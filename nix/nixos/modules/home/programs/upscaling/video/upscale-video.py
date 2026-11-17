#!/usr/bin/env python3
"""Bounded-frame, offline SDR/CFR upscaling. No service management or network IO."""

import argparse
import fcntl
from fractions import Fraction
import json
import math
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time

from PIL import Image


PROFILES = {
    "ugc": ("realesrgan-x4plus", 4),
    "cartoon": ("realesr-animevideov3", 2),
}


class UpscaleError(Exception):
    pass


def probe(path, count=False):
    command = ["ffprobe", "-v", "error"]
    if count:
        command += ["-count_frames"]
    result = subprocess.run(
        command + ["-show_streams", "-show_format", "-of", "json", str(path)],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)


def video_stream(info):
    streams = [
        s
        for s in info["streams"]
        if s["codec_type"] == "video"
        and not s.get("disposition", {}).get("attached_pic")
    ]
    if len(streams) != 1:
        raise UpscaleError("Exactly one non-attached video stream is supported.")
    return streams[0]


def validate_source(info):
    stream = video_stream(info)
    if (
        stream.get("color_transfer")
        in {"smpte2084", "arib-std-b67", "bt2020-10", "bt2020-12"}
        or stream.get("color_primaries") == "bt2020"
        or stream.get("color_space") in {"bt2020nc", "bt2020c"}
    ):
        raise UpscaleError(
            "HDR/wide-gamut input is unsupported; convert to SDR explicitly first."
        )
    pixel_format = stream.get("pix_fmt", "")
    if pixel_format not in {
        "yuv420p",
        "yuvj420p",
        "yuv422p",
        "yuvj422p",
        "yuv444p",
        "yuvj444p",
        "rgb24",
        "bgr24",
        "gbrp",
        "nv12",
    }:
        raise UpscaleError(
            f"Unsupported pixel format {pixel_format!r}; use opaque 8-bit SDR input."
        )
    if stream.get("field_order", "progressive") not in {"progressive", "unknown"}:
        raise UpscaleError(
            "Interlaced input is unsupported; deinterlace explicitly first."
        )
    if stream.get("sample_aspect_ratio", "1:1") not in {"1:1", "N/A", "0:1"}:
        raise UpscaleError(
            "Non-square pixels are unsupported; normalize sample aspect ratio first."
        )
    rotations = [s.get("rotation", 0) for s in stream.get("side_data_list", [])]
    if (
        any(float(r) % 360 for r in rotations)
        or float(stream.get("tags", {}).get("rotate", 0)) % 360
    ):
        raise UpscaleError(
            "Rotation metadata is unsupported; bake rotation into pixels first."
        )
    try:
        rate = Fraction(stream["avg_frame_rate"])
        nominal = Fraction(stream["r_frame_rate"])
        if rate <= 0 or nominal <= 0 or abs(float(rate / nominal) - 1) > 0.001:
            raise ValueError()
    except (ValueError, ZeroDivisionError, KeyError):
        raise UpscaleError(
            "Input must have a valid constant frame rate (VFR is unsupported)."
        ) from None
    # The v1 mux path assumes aligned, zero-based source streams.
    for s in [stream] + [s for s in info["streams"] if s["codec_type"] == "audio"]:
        if abs(float(s.get("start_time", 0))) > 0.001:
            raise UpscaleError(
                "Nonzero stream start times are unsupported; normalize timestamps first."
            )
    return stream, rate


def validate_timestamps(path, stream, rate):
    """Stream ffprobe output: average/nominal rates alone do not prove CFR."""
    command = [
        "ffprobe",
        "-v",
        "error",
        "-select_streams",
        str(stream["index"]),
        "-show_entries",
        "frame=best_effort_timestamp_time",
        "-of",
        "csv=p=0",
        str(path),
    ]
    period = float(1 / rate)
    tolerance = max(0.00001, 1.1 * float(Fraction(stream.get("time_base", "1/1000"))))
    previous = None
    frames = 0
    with tempfile.TemporaryFile() as errors:
        with subprocess.Popen(
            command, stdout=subprocess.PIPE, stderr=errors, text=True
        ) as process:
            try:
                for line in process.stdout:
                    value = line.strip().split(",")[0]
                    if not value:
                        continue  # ffprobe may emit a blank side-data line
                    try:
                        stamp = float(value)
                    except ValueError:
                        raise UpscaleError(
                            "Missing frame timestamps; cannot establish CFR."
                        ) from None
                    if not math.isfinite(stamp) or (
                        previous is not None
                        and abs(stamp - previous - period) > tolerance
                    ):
                        raise UpscaleError(
                            "Variable or discontinuous frame timestamps; VFR is unsupported."
                        )
                    previous = stamp
                    frames += 1
            except BaseException:
                process.terminate()
                raise
            if process.wait() != 0:
                raise UpscaleError("ffprobe timestamp scan failed.")
    if not frames:
        raise UpscaleError("Input contains no decoded frames.")


def target_size(width, height, size):
    short = int(size.removesuffix("p"))
    long = short * 16 / 9
    box_w, box_h = (long, short) if width >= height else (short, long)
    scale = min(box_w / width, box_h / height)
    return max(2, round(width * scale / 2) * 2), max(2, round(height * scale / 2) * 2)


def read_frame(pipe, length):
    data = bytearray()
    while len(data) < length:
        part = pipe.read(length - len(data))
        if not part:
            if data:
                raise UpscaleError("Decoder produced a truncated frame.")
            return None
        data.extend(part)
    return bytes(data)


def run_logged(command, log):
    with log.open("ab") as output:
        output.write(("\n$ " + repr(command) + "\n").encode())
        output.flush()
        subprocess.run(command, stdout=output, stderr=output, check=True)


def selection(args):
    result = ["-ss", str(args.start)] if args.start else []
    return result


def stop(process):
    if process is not None:
        if process.poll() is None:
            process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
        for pipe in (process.stdin, process.stdout):
            if pipe:
                try:
                    pipe.close()
                except BrokenPipeError:
                    pass


def pipeline(args, stream, rate, work):
    model, scale = PROFILES[args.profile]
    width, height = stream["width"], stream["height"]
    out_w, out_h = target_size(width, height, args.size)
    source_frames, enlarged = work / "input", work / "upscaled"
    source_frames.mkdir()
    enlarged.mkdir()
    video = work / "video.mp4"
    log = work / "process.log"
    decoder_command = [
        "ffmpeg",
        "-nostdin",
        "-v",
        "error",
        "-threads",
        "2",
    ] + selection(args)
    decoder_command += ["-i", str(args.input), "-map", f"0:{stream['index']}"]
    if args.duration is not None:
        decoder_command += [
            "-frames:v",
            str(math.ceil(Fraction(str(args.duration)) * rate)),
        ]
    decoder_command += [
        "-an",
        "-sn",
        "-dn",
        "-fps_mode",
        "passthrough",
        "-filter_threads",
        "1",
        "-threads",
        "2",
        "-pix_fmt",
        "rgb24",
        "-f",
        "rawvideo",
        "pipe:1",
    ]
    encoder_command = [
        "ffmpeg",
        "-nostdin",
        "-v",
        "error",
        "-threads",
        "2",
        "-f",
        "image2pipe",
        "-framerate",
        str(rate),
        "-c:v",
        "png",
        "-i",
        "pipe:0",
        "-an",
        "-filter_threads",
        "1",
        "-vf",
        f"scale={out_w}:{out_h}:flags=lanczos,setsar=1",
        "-c:v",
        "libx264",
        "-threads",
        "2",
        "-preset",
        "medium",
        "-crf",
        str(args.crf),
        "-pix_fmt",
        "yuv420p",
        "-movflags",
        "+faststart",
        str(video),
    ]
    decoder = encoder = None
    frames = 0
    peak_scratch = 0
    began = time.monotonic()
    with log.open("ab") as errors:
        try:
            decoder = subprocess.Popen(
                decoder_command, stdout=subprocess.PIPE, stderr=errors
            )
            encoder = subprocess.Popen(
                encoder_command, stdin=subprocess.PIPE, stdout=errors, stderr=errors
            )
            while True:
                names = []
                # PNG can approach uncompressed size on noisy generated frames.
                # Reserve a conservative full chunk plus a little encoder headroom.
                multiplier = 1 + scale * scale if args.method == "ai" else 1
                reserve = (
                    width * height * 4 * multiplier * args.chunk_size
                    + 128 * 1024 * 1024
                )
                if shutil.disk_usage(work).free < reserve:
                    raise UpscaleError(
                        "Insufficient scratch space for another chunk; use --scratch-dir or a smaller --chunk-size."
                    )
                for index in range(args.chunk_size):
                    raw = read_frame(decoder.stdout, width * height * 3)
                    if raw is None:
                        break
                    name = f"{index:08d}.png"
                    Image.frombytes("RGB", (width, height), raw).save(
                        source_frames / name
                    )
                    names.append(name)
                if not names:
                    break
                if args.method == "ai":
                    run_logged(
                        [
                            "realesrgan-ncnn-vulkan",
                            "-i",
                            str(source_frames),
                            "-o",
                            str(enlarged),
                            "-m",
                            str(args.models),
                            "-n",
                            model,
                            "-s",
                            str(scale),
                            "-t",
                            str(args.tile),
                            "-g",
                            str(args.gpu),
                            "-j",
                            "1:1:1",
                            "-f",
                            "png",
                        ],
                        log,
                    )
                peak_scratch = max(
                    peak_scratch,
                    sum(p.stat().st_size for p in work.rglob("*") if p.is_file()),
                )
                for name in names:
                    image_path = (
                        enlarged if args.method == "ai" else source_frames
                    ) / name
                    with Image.open(image_path) as image:
                        expected = (
                            (width * scale, height * scale)
                            if args.method == "ai"
                            else (width, height)
                        )
                        if image.size != expected:
                            raise UpscaleError(
                                f"Unexpected model output dimensions: {image.size}, expected {expected}."
                            )
                        image.verify()
                    with image_path.open("rb") as image_file:
                        shutil.copyfileobj(image_file, encoder.stdin)
                    (source_frames / name).unlink()
                    if args.method == "ai":
                        image_path.unlink()
                frames += len(names)
                elapsed = time.monotonic() - began
                print(
                    f"{frames} frames; {frames / elapsed:.2f} fps; scratch: {work}",
                    file=sys.stderr,
                )
            if decoder.wait() != 0:
                raise UpscaleError("FFmpeg decoder failed; see process.log.")
            encoder.stdin.close()
            if encoder.wait() != 0:
                raise UpscaleError("FFmpeg encoder failed; see process.log.")
        finally:
            stop(decoder)
            stop(encoder)
    if not frames:
        raise UpscaleError("Selection contains no frames; check --start/--duration.")
    result = work / "result.mp4"
    source_info = probe(args.input)
    audio = next(
        (s for s in source_info["streams"] if s["codec_type"] == "audio"), None
    )
    command = ["ffmpeg", "-nostdin", "-v", "error", "-i", str(video)]
    if audio:
        command += selection(args) + [
            "-i",
            str(args.input),
            "-map",
            "0:v:0",
            "-map",
            f"1:{audio['index']}",
        ]
        copy_audio = (
            not args.start
            and args.duration is None
            and audio.get("codec_name") in {"aac", "mp3"}
        )
        command += ["-c:a", "copy"] if copy_audio else ["-c:a", "aac", "-b:a", "192k"]
    else:
        command += ["-map", "0:v:0"]
    command += [
        "-c:v",
        "copy",
        "-t",
        str(float(frames / rate)),
        "-map_metadata",
        "-1",
        "-movflags",
        "+faststart",
        str(result),
    ]
    run_logged(command, log)
    result_info = probe(result, count=True)
    actual = video_stream(result_info)
    if (actual["width"], actual["height"]) != (out_w, out_h) or int(
        actual.get("nb_read_frames", 0)
    ) != frames:
        raise UpscaleError(
            "Output validation failed: dimensions or decoded frame count differ."
        )
    if Fraction(actual["avg_frame_rate"]) != rate:
        raise UpscaleError("Output validation failed: frame rate changed.")
    expected_duration = float(frames / rate)
    if abs(float(actual["duration"]) - expected_duration) > max(0.002, float(1 / rate)):
        raise UpscaleError("Output validation failed: video duration changed.")
    if audio and not any(s["codec_type"] == "audio" for s in result_info["streams"]):
        raise UpscaleError("Output validation failed: audio missing.")
    peak_scratch = max(
        peak_scratch, sum(p.stat().st_size for p in work.rglob("*") if p.is_file())
    )
    return result, {
        "frames": frames,
        "fps": str(rate),
        "width": out_w,
        "height": out_h,
        "observed_peak_scratch_bytes": peak_scratch,
        "pipeline_seconds": round(time.monotonic() - began, 3),
        "method": args.method,
        "profile": args.profile,
        "model": model if args.method == "ai" else None,
    }


def publish(source, destination):
    """Stage on the destination filesystem; link atomically without clobbering."""
    fd, name = tempfile.mkstemp(
        prefix=f".{destination.name}.", suffix=".partial", dir=destination.parent
    )
    staged = Path(name)
    try:
        with os.fdopen(fd, "wb") as output, source.open("rb") as input_file:
            shutil.copyfileobj(input_file, output)
            output.flush()
            os.fsync(output.fileno())
        os.link(staged, destination)  # EEXIST protects against destination races, too.
    finally:
        staged.unlink(missing_ok=True)


def nonnegative(value):
    number = float(value)
    if not math.isfinite(number) or number < 0:
        raise argparse.ArgumentTypeError("must be a finite nonnegative number")
    return number


def positive_int(value):
    number = int(value)
    if number < 1:
        raise argparse.ArgumentTypeError("must be a positive integer")
    return number


def parser():
    p = argparse.ArgumentParser(prog="upscale-video", description=__doc__)
    p.add_argument("input", type=Path)
    p.add_argument("output", type=Path)
    p.add_argument("--profile", choices=PROFILES, default="ugc")
    p.add_argument(
        "--method",
        choices=["ai", "lanczos"],
        default="ai",
        help="lanczos is a CPU-only comparison baseline",
    )
    p.add_argument(
        "--size", choices=["720p", "1080p", "1440p", "2160p"], default="1080p"
    )
    p.add_argument("--start", type=nonnegative, default=0)
    p.add_argument(
        "--duration", type=nonnegative, help="preview length in seconds (must be > 0)"
    )
    p.add_argument(
        "--tile", type=positive_int, default=os.environ.get("UPSCALE_VIDEO_TILE", "128")
    )
    p.add_argument("--gpu", type=int, default=os.environ.get("UPSCALE_VIDEO_GPU", "0"))
    p.add_argument(
        "--chunk-size",
        type=positive_int,
        default=os.environ.get("UPSCALE_VIDEO_CHUNK", "8"),
    )
    p.add_argument(
        "--crf",
        type=int,
        choices=range(52),
        default=os.environ.get("UPSCALE_VIDEO_CRF", "18"),
        metavar="0..51",
    )
    p.add_argument(
        "--scratch-dir",
        type=Path,
        default=os.environ.get(
            "UPSCALE_VIDEO_SCRATCH",
            str(
                Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
                / "upscaling"
            ),
        ),
    )
    p.add_argument(
        "--models",
        type=Path,
        default=os.environ.get("UPSCALE_VIDEO_MODELS"),
        help="directory containing packaged NCNN .bin/.param models",
    )
    return p


def execute(args):
    began = time.monotonic()
    args.input = args.input.expanduser().resolve(strict=True)
    args.output = args.output.expanduser().absolute()
    if not args.input.is_file() or args.output.exists() or args.output.is_symlink():
        raise UpscaleError(
            "Input must be a file and output must not exist; overwriting is never allowed."
        )
    if args.output.suffix.lower() != ".mp4" or not args.output.parent.is_dir():
        raise UpscaleError("Output must be an .mp4 in an existing directory.")
    if args.duration == 0 or args.tile < 32 or args.gpu < 0:
        raise UpscaleError("Duration must be positive, tile >= 32, and GPU index >= 0.")
    if args.method == "ai":
        model, scale = PROFILES[args.profile]
        base = f"{model}-x{scale}" if model == "realesr-animevideov3" else model
        if args.models is None or any(
            not (args.models / f"{base}.{ext}").is_file() for ext in ("param", "bin")
        ):
            raise UpscaleError(
                "Model files missing; use the Nix wrapper or supply --models."
            )
    args.scratch_dir = args.scratch_dir.expanduser().resolve()
    args.scratch_dir.mkdir(parents=True, exist_ok=True)
    # A fixed per-user lock: changing scratch directories must not bypass it.
    lock_dir = (
        Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "upscaling"
    )
    lock_dir.mkdir(parents=True, exist_ok=True)
    with (lock_dir / "video.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise UpscaleError(
                "Another upscale-video job is running for this user."
            ) from None
        stream, rate = validate_source(probe(args.input))
        print("Checking frame timestamps (CFR only)...", file=sys.stderr)
        validate_timestamps(args.input, stream, rate)
        if args.start:
            # Select the first frame at/after the requested time. Round the seek
            # down to microseconds so FFmpeg cannot skip that frame by rounding.
            first = math.ceil(Fraction(str(args.start)) * rate)
            args.start = math.floor(first / rate * 1_000_000) / 1_000_000
        if args.method == "ai":
            print(
                "AI upscaling never stops services. On home-server: gpu-lease -- upscale-video ...",
                file=sys.stderr,
            )
        work = Path(tempfile.mkdtemp(prefix="video-", dir=args.scratch_dir))
        print(f"Job scratch/logs: {work}", file=sys.stderr)
        try:
            result, stats = pipeline(args, stream, rate, work)
            (work / "stats.json").write_text(json.dumps(stats, indent=2) + "\n")
            publish(result, args.output)
        except BaseException as error:
            try:
                (work / "error.txt").write_text(f"{type(error).__name__}: {error}\n")
            except OSError:
                pass  # Disk exhaustion must not prevent cleanup.
            # Retain small diagnostics, not potentially gigabytes of intermediate frames.
            for directory in (work / "input", work / "upscaled"):
                shutil.rmtree(directory, ignore_errors=True)
            for name in ("video.mp4", "result.mp4"):
                (work / name).unlink(missing_ok=True)
            print(f"Failed; diagnostics retained at {work}", file=sys.stderr)
            raise
        shutil.rmtree(work)
        stats["processing_seconds"] = round(time.monotonic() - began, 3)
        print(json.dumps({"output": str(args.output), **stats}))


def main():
    def interrupted(_signum, _frame):
        raise KeyboardInterrupt

    signal.signal(signal.SIGTERM, interrupted)
    args = parser().parse_args()
    try:
        execute(args)
    except KeyboardInterrupt:
        print("Interrupted; no output published.", file=sys.stderr)
        return 130
    except (
        UpscaleError,
        OSError,
        subprocess.CalledProcessError,
        ValueError,
        KeyError,
    ) as error:
        print(f"upscale-video: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
