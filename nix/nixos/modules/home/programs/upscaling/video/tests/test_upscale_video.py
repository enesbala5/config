import fcntl
from fractions import Fraction
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "upscale-video.py"
spec = importlib.util.spec_from_file_location("upscale_video", SCRIPT)
uv = importlib.util.module_from_spec(spec)
spec.loader.exec_module(uv)


class Helpers(unittest.TestCase):
    def source(self, **values):
        return {
            "streams": [
                {
                    "index": 0,
                    "codec_type": "video",
                    "width": 1280,
                    "height": 720,
                    "avg_frame_rate": "30000/1001",
                    "r_frame_rate": "30000/1001",
                    "pix_fmt": "yuv420p",
                    **values,
                }
            ]
        }

    def test_sizing(self):
        for dims, expected in [
            ((1280, 720), (1920, 1080)),
            ((720, 1280), (1080, 1920)),
            ((1000, 1000), (1080, 1080)),
            ((853, 480), (1920, 1080)),
        ]:
            self.assertEqual(uv.target_size(*dims, "1080p"), expected)
        self.assertTrue(all(n % 2 == 0 for n in uv.target_size(777, 999, "1080p")))

    def test_fractional_rate(self):
        self.assertEqual(uv.validate_source(self.source())[1], Fraction(30000, 1001))

    def test_unsupported_sources(self):
        for values in [
            {"color_transfer": "smpte2084"},
            {"color_transfer": "arib-std-b67"},
            {"color_primaries": "bt2020"},
            {"pix_fmt": "yuv420p10le"},
            {"pix_fmt": "rgba"},
            {"avg_frame_rate": "0/0"},
            {"avg_frame_rate": "24", "r_frame_rate": "30"},
            {"sample_aspect_ratio": "4:3"},
            {"start_time": "0.5"},
            {"field_order": "tt"},
            {"side_data_list": [{"rotation": 90}]},
        ]:
            with self.subTest(values=values), self.assertRaises(uv.UpscaleError):
                uv.validate_source(self.source(**values))

    def test_timestamp_scan_checks_actual_cadence(self):
        import io

        stream = {"index": 0, "time_base": "1/30000"}
        for stamps, valid in [
            ("0\n0.033333\n0.066667\n", True),
            ("0\n0.033333\n0.083333\n", False),
            ("N/A\n", False),
            ("", False),
        ]:
            with (
                self.subTest(stamps=stamps),
                patch.object(uv.subprocess, "Popen") as popen,
            ):
                process = popen.return_value.__enter__.return_value
                process.stdout = io.StringIO(stamps)
                process.wait.return_value = 0
                if valid:
                    uv.validate_timestamps(Path("unused.mp4"), stream, Fraction(30))
                else:
                    with self.assertRaises(uv.UpscaleError):
                        uv.validate_timestamps(Path("unused.mp4"), stream, Fraction(30))

    def test_partial_frame(self):
        import io

        self.assertEqual(uv.read_frame(io.BytesIO(b"abc"), 3), b"abc")
        self.assertIsNone(uv.read_frame(io.BytesIO(), 3))
        with self.assertRaises(uv.UpscaleError):
            uv.read_frame(io.BytesIO(b"ab"), 3)

    def test_publish_no_clobber(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            source, dest = root / "source", root / "dest"
            source.write_bytes(b"new")
            dest.write_bytes(b"old")
            with self.assertRaises(FileExistsError):
                uv.publish(source, dest)
            self.assertEqual(dest.read_bytes(), b"old")
            self.assertEqual(sorted(p.name for p in root.iterdir()), ["dest", "source"])
            dest.unlink()
            uv.publish(source, dest)
            self.assertEqual(dest.read_bytes(), b"new")


class Integration(unittest.TestCase):
    """Real FFmpeg/Pillow pipeline; mock only the GPU executable."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.env = {**os.environ, "XDG_CACHE_HOME": str(self.root / "cache")}
        self.input = self.root / "source with spaces.mp4"
        self.output = self.root / "output with spaces.mp4"
        self.ffmpeg(
            [
                "-f",
                "lavfi",
                "-i",
                "testsrc2=size=32x18:rate=30000/1001:duration=0.21",
                "-f",
                "lavfi",
                "-i",
                "sine=frequency=440:duration=0.234",
                "-c:v",
                "libx264",
                "-threads",
                "2",
                "-pix_fmt",
                "yuv420p",
                "-c:a",
                "aac",
                str(self.input),
            ]
        )

    def ffmpeg(self, args):
        subprocess.run(
            ["ffmpeg", "-nostdin", "-v", "error", "-filter_threads", "1", *args],
            check=True,
            capture_output=True,
        )

    def cli(self, *extra, success=True, input_path=None, env=None):
        command = [
            sys.executable,
            str(SCRIPT),
            str(input_path or self.input),
            str(self.output),
            "--method",
            "lanczos",
            "--size",
            "720p",
            "--chunk-size",
            "2",
            *map(str, extra),
        ]
        result = subprocess.run(
            command, env=env or self.env, capture_output=True, text=True, timeout=60
        )
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return result

    def inspect(self, frames, portrait=False, audio=True):
        info = uv.probe(self.output, count=True)
        video = uv.video_stream(info)
        self.assertEqual(
            (video["width"], video["height"]), (720, 1280) if portrait else (1280, 720)
        )
        self.assertEqual(int(video["nb_read_frames"]), frames)
        self.assertEqual(Fraction(video["avg_frame_rate"]), Fraction(30000, 1001))
        self.assertEqual(
            any(s["codec_type"] == "audio" for s in info["streams"]), audio
        )
        self.assertAlmostEqual(
            float(video["duration"]), float(frames * Fraction(1001, 30000)), places=3
        )
        if audio:
            track = next(s for s in info["streams"] if s["codec_type"] == "audio")
            self.assertLess(
                abs(float(track["duration"]) - float(video["duration"])), 0.06
            )
        self.assertFalse(list((self.root / "cache" / "upscaling").glob("video-*")))

    def test_multichunk_fractional_audio_and_existing_output(self):
        result = self.cli()
        stats = json.loads(result.stdout)
        self.assertEqual(stats["frames"], 7)
        self.inspect(7)
        before = self.output.read_bytes()
        self.cli(success=False)
        self.assertEqual(self.output.read_bytes(), before)

    def test_preview(self):
        self.cli("--start", ".067", "--duration", ".1")
        self.inspect(3)

    def test_portrait_without_audio(self):
        source = self.root / "portrait.mp4"
        self.ffmpeg(
            [
                "-f",
                "lavfi",
                "-i",
                "testsrc2=size=18x32:rate=30000/1001:duration=0.07",
                "-c:v",
                "libx264",
                "-threads",
                "2",
                "-pix_fmt",
                "yuv420p",
                str(source),
            ]
        )
        self.cli(input_path=source)
        self.inspect(3, portrait=True, audio=False)

    def mock_ai(self, fail=False):
        binary = self.root / "realesrgan-ncnn-vulkan"
        binary.write_text(
            f"#!{sys.executable}\n"
            + (
                "import sys\nsys.exit(42)\n"
                if fail
                else "import sys\nfrom pathlib import Path\nfrom PIL import Image\n"
                "args=sys.argv\nsource=Path(args[args.index('-i')+1])\ndest=Path(args[args.index('-o')+1])\n"
                "scale=int(args[args.index('-s')+1])\n"
                "for path in source.glob('*.png'):\n"
                "    with Image.open(path) as im:\n"
                "        im.resize((im.width*scale,im.height*scale)).save(dest/path.name)\n"
            )
        )
        binary.chmod(0o755)
        models = self.root / "models"
        models.mkdir()
        for model in ("realesrgan-x4plus", "realesr-animevideov3-x2"):
            for suffix in ("bin", "param"):
                (models / f"{model}.{suffix}").touch()
        return models, {
            **self.env,
            "PATH": str(self.root) + os.pathsep + os.environ["PATH"],
        }

    def test_both_ai_profiles(self):
        models, env = self.mock_ai()
        for profile in ("ugc", "cartoon"):
            with self.subTest(profile=profile):
                self.cli(
                    "--method", "ai", "--profile", profile, "--models", models, env=env
                )
                self.inspect(7)
                self.output.unlink()

    def test_failure_keeps_logs_cleans_frames(self):
        models, env = self.mock_ai(fail=True)
        self.cli("--method", "ai", "--models", models, env=env, success=False)
        self.assertFalse(self.output.exists())
        jobs = list((self.root / "cache" / "upscaling").glob("video-*"))
        self.assertEqual(len(jobs), 1)
        self.assertTrue((jobs[0] / "process.log").is_file())
        self.assertFalse((jobs[0] / "input").exists())
        self.assertFalse((jobs[0] / "upscaled").exists())
        self.assertFalse(list(jobs[0].glob("*.mp4")))

    def test_low_disk_space_fails_before_staging_frames(self):
        args = uv.parser().parse_args(
            [str(self.input), str(self.output), "--method", "lanczos"]
        )
        with (
            patch.dict(os.environ, self.env),
            patch.object(uv.shutil, "disk_usage") as usage,
        ):
            args.scratch_dir = self.root / "cache" / "upscaling"
            usage.return_value.free = 0
            with self.assertRaisesRegex(uv.UpscaleError, "Insufficient scratch space"):
                uv.execute(args)
        self.assertFalse(self.output.exists())
        jobs = list((self.root / "cache" / "upscaling").glob("video-*"))
        self.assertEqual(len(jobs), 1)
        self.assertTrue((jobs[0] / "error.txt").is_file())
        self.assertFalse((jobs[0] / "input").exists())

    def test_lock_is_independent_of_scratch(self):
        root = self.root / "cache" / "upscaling"
        root.mkdir(parents=True)
        with (root / "video.lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            result = self.cli("--scratch-dir", self.root / "different", success=False)
            self.assertIn("Another upscale-video job", result.stderr)

    def test_invalid_and_empty_selection(self):
        self.cli("--duration", "0", success=False)
        self.cli("--start", "nan", success=False)
        self.cli(input_path=self.root / "missing.mp4", success=False)
        self.cli("--start", "99", success=False)
        self.assertFalse(self.output.exists())

    def test_vfr_rejected(self):
        source = self.root / "vfr.mp4"
        self.ffmpeg(
            [
                "-f",
                "lavfi",
                "-i",
                "testsrc2=size=32x18:rate=30:duration=0.3",
                "-vf",
                "select='not(eq(n,3))'",
                "-fps_mode",
                "vfr",
                "-c:v",
                "libx264",
                "-threads",
                "2",
                str(source),
            ]
        )
        self.assertIn("VFR", self.cli(input_path=source, success=False).stderr)

    def batch(self, inputs, *extra, success=True, env=None):
        command = [
            sys.executable,
            str(SCRIPT),
            "--out-dir",
            str(self.root / "out"),
            "--status-file",
            str(self.root / "status.json"),
            "--method",
            "lanczos",
            "--size",
            "720p",
            "--chunk-size",
            "2",
            *map(str, extra),
            "--",
            *map(str, inputs),
        ]
        result = subprocess.run(
            command, env=env or self.env, capture_output=True, text=True, timeout=120
        )
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return result

    def status(self):
        return json.loads((self.root / "status.json").read_text())

    def second_input(self):
        second = self.root / "second.mp4"
        second.write_bytes(self.input.read_bytes())
        return second

    def test_batch_runs_every_input_and_reports_status(self):
        second = self.second_input()
        result = self.batch([self.input, second])
        self.assertEqual(len(result.stdout.strip().splitlines()), 2)
        out = self.root / "out"
        self.assertEqual(
            sorted(p.name for p in out.iterdir()),
            ["second.mp4", "source with spaces.mp4"],
        )
        status = self.status()
        self.assertEqual(status["state"], "done")
        self.assertEqual([f["state"] for f in status["files"]], ["done", "done"])
        self.assertEqual(status["files"][0]["frames"], 7)
        self.assertEqual(status["files"][0]["frames_total"], 7)
        self.assertFalse(list(self.root.glob(".*.tmp")))

    def test_batch_rerun_skips_finished_outputs(self):
        second = self.second_input()
        self.batch([self.input])
        done = self.root / "out" / "source with spaces.mp4"
        before = done.read_bytes()
        result = self.batch([self.input, second])
        self.assertEqual(len(result.stdout.strip().splitlines()), 1)
        self.assertEqual(done.read_bytes(), before)
        self.assertEqual(
            [f["state"] for f in self.status()["files"]], ["skipped", "done"]
        )

    def test_batch_stops_at_first_failure_and_names_the_file(self):
        second = self.second_input()
        models, env = self.mock_ai(fail=True)
        result = self.batch(
            [self.input, second], "--method", "ai", "--models", models, env=env,
            success=False,
        )
        self.assertIn("source with spaces.mp4:", result.stderr)
        status = self.status()
        self.assertEqual(status["state"], "failed")
        self.assertEqual([f["state"] for f in status["files"]], ["failed", "queued"])
        self.assertTrue(status["files"][0]["error"])
        self.assertEqual(list((self.root / "out").iterdir()), [])

    def test_batch_refuses_clobbering_names(self):
        second = self.root / "sub" / self.input.name
        second.parent.mkdir()
        second.write_bytes(self.input.read_bytes())
        result = self.batch([self.input, second], success=False)
        self.assertIn("Two inputs would write", result.stderr)
        # An input already named <stem>.mp4 inside --out-dir would be skipped
        # as "done" instead of processed, so it is rejected up front.
        out = self.root / "out"
        out.mkdir(exist_ok=True)
        inside = out / "inside.mp4"
        inside.write_bytes(self.input.read_bytes())
        result = self.batch([inside], success=False)
        self.assertIn("would overwrite the input", result.stderr)

    def test_positional_shapes(self):
        for args in (
            [str(self.input)],
            [str(self.input), str(self.output), str(self.root / "third.mp4")],
        ):
            result = subprocess.run(
                [sys.executable, str(SCRIPT), *args],
                env=self.env,
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 2)
            self.assertIn("expected INPUT OUTPUT", result.stderr)


if __name__ == "__main__":
    unittest.main()
