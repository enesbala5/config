# Local video upscaling

Opt-in Home Manager tools for offline upscaling of AI-generated UGC and cartoons.
Runs FFmpeg + Real-ESRGAN NCNN/Vulkan locally; no CUDA, ROCm, Python ML framework,
network service, automatic privileged operations, or runtime model downloads.

## Enable

The shared `programs/default.nix` imports this module. Everything is disabled by
default; only `hosts/home-server/home/default.nix` enables it:

```nix
modules.home.upscaling = {
  enable = true;
  video = {
    enable = true;
    # Defaults; override only after testing.
    tileSize = 128;
    gpu = 0;
    chunkSize = 8;
    crf = 18;
    # Optional: an existing disk-backed parent on a roomier drive.
    # scratchDirectory = "/path/to/upscaling-scratch";
  };
};
```

`video.package` and `video.ffmpegPackage` are overridable. A replacement model
package must supply `realesrgan-ncnn-vulkan` and compatible weights under
`share/models`. The locked Nixpkgs package includes the models used below and
patches its default model path. The wrapper also passes that directory explicitly.

Hardware setup belongs to NixOS, not Home Manager. `home-server` already enables
`hardware.graphics`; verify render-device access as the actual invoking user.
No `image/` placeholder exists: add an image module when it has functionality.

## Before using the RX 570

The server's `llama-cpp.service` also uses this 4 GB card. **Do not assume tiled
upscaling can coexist with a loaded LLM.** This tool never stops or restarts it.

On `home-server`, as user `e`:

```bash
vulkaninfo --summary
ls -l /dev/dri/renderD*
systemctl is-active llama-cpp.service
```

Confirm Vulkan lists the real AMD GPU, not only a software renderer such as
llvmpipe. If device permissions fail, inspect render/video group membership and
NixOS device permissions before changing anything; log in again after group changes.
The NCNN GPU index can differ from the DRM card number. Its log lists detected GPUs.

When you can interrupt inference, `gpu-lease` stops `llama-cpp.service` for one
command and starts it again only if this command stopped it. A service you had
left stopped stays stopped. In-flight `/v1` requests end when the unit stops, and
`http://home-server:8080/v1` is down until the command exits.

```bash
gpu-lease -- upscale-video input.mp4 output.mp4 --profile ugc

# SIGKILL skips the restore trap. If inference does not come back:
sudo systemctl start llama-cpp.service
```

Prefer `hc` for jobs that should survive disconnects:

```bash
hc run --bg 'gpu-lease -- upscale-video input.mp4 output.mp4 --profile cartoon'
```

No extra ports, firewall rules, root-run upscaler, or always-on worker are required.

## Usage (after deploying the configuration)

On `home-server`, put `gpu-lease --` in front of AI runs. `--method lanczos` does not
use the GPU. Commands run on the machine holding the GPU and input files; there is no implicit
SSH transfer or remote backend. Copy files with SSH/SFTP or use an existing mount.

```bash
# Landscape 720p -> 1080p, or portrait 720x1280 -> 1080x1920.
upscale-video input.mp4 output.mp4 --profile ugc

upscale-video cartoon.mp4 cartoon-1080.mp4 --profile cartoon --size 1080p

# First make a short preview. Start rounds up to the next source frame;
# duration rounds up to a whole frame count (at most one extra frame).
upscale-video input.mp4 preview.mp4 \
  --profile ugc --start 5 --duration 3

# CPU-only Lanczos comparison: no Vulkan or model files needed.
upscale-video input.mp4 baseline.mp4 \
  --method lanczos --start 5 --duration 3

# Lower tiles reduce model memory requirements. Smaller chunks reduce disk use,
# not per-frame model VRAM. Model startup repeats once per chunk.
upscale-video input.mp4 output.mp4 \
  --profile ugc --tile 64 --chunk-size 4 --gpu 0

hc run --bg 'gpu-lease -- upscale-video input.mp4 output.mp4 --profile cartoon'
# Keep the returned task ID; use hc read <id> and hc wait <id>.
```

Output must be `.mp4` in an existing directory and **must not already exist**.
No overwrite flag is provided. Input is never modified. Spaces in filenames work.

`--size` supports `720p`, `1080p`, `1440p`, and `2160p`. Sizes are landscape or
portrait 16:9 bounding boxes. Other aspect ratios fit inside them without cropping,
padding, or stretching; dimensions round to even pixels for H.264. A square source
at `1080p` becomes 1080x1080. Larger targets are not necessarily useful on this GPU.

### Profiles

| Profile | Packaged model | Model scale | Intended starting point |
| --- | --- | --- | --- |
| `ugc` | `realesrgan-x4plus` | 4x | Photorealistic generated people/scenes |
| `cartoon` | `realesr-animevideov3` | 2x | Animation, particularly line-art/anime |

The model's fixed scale is separate from output resolution. UGC uses a 4x model
because this packaged general model is not a native 2x model; its output is resized
down to the target. That intermediate costs more time and scratch space than the
cartoon 2x model. Do not pass `-s 2` to the general 4x model as an optimization.

These profiles are **unbenchmarked starting points**, not guarantees of improvement.
The anime-video model still processes individual frames here; the pipeline does
not use temporal context. For textured/3D cartoons, compare both profiles. No face
restoration, sharpening pass, interpolation, or TTA is enabled.

### Pipeline and storage

1. Probe metadata and scan frame timestamps to verify CFR before processing.
2. Decode selected frames through a raw RGB pipe; stage at most one PNG chunk.
3. Invoke the model once per chunk (`1:1:1` load/process/save threads, one GPU).
4. Feed processed PNGs to one persistent FFmpeg encoder, preserving rational FPS.
5. Encode H.264, `yuv420p`, CRF 18, medium preset, CPU encoding (two threads).
6. Mux the first audio stream. Full-length AAC/MP3 can be copied; previews and
   other codecs use AAC at 192 kb/s for accurate selection/container compatibility.
7. Decode-count the result and validate dimensions, FPS, frame count, duration,
   and audio presence; stage a copy beside the destination and publish without
   overwriting, even if another process creates that destination meanwhile.

The default scratch parent is `$XDG_CACHE_HOME/upscaling`, falling back to
`~/.cache/upscaling`; it deliberately does not use `/tmp`. Use `--scratch-dir` for
another disk-backed location. The code cannot guarantee that your home/cache is
not itself on tmpfs: choose the directory accordingly.

Only the **frame staging** is bounded. The encoded video and muxed MP4 accumulate
on scratch; final publication also needs room for a destination-side copy. For a
720p UGC chunk of eight frames, a conservative uncompressed staging estimate is
roughly 0.5 GB. Noisy PNGs compress poorly; leave several GB free for real videos.
A conservative free-space check runs per chunk. Disk exhaustion still fails safely.

Success removes job scratch and prints one JSON summary on stdout: frame count,
FPS, size, model, processing seconds, and observed scratch bytes. `processing_seconds`
includes timestamp scanning, encoding, validation, and publication; `pipeline_seconds`
excludes initial validation and publication. Progress and scratch paths go to stderr. The observed scratch peak is sampled at chunk/mux
boundaries, not a continuously measured filesystem or VRAM peak. Save the summary
if you want a benchmark record (`... > result.json`).

Failures, Ctrl-C, and SIGTERM remove staged frames/video but retain the job folder
with `process.log` and `error.txt`. Early validation failures create no job folder.
Hard kills/power loss can leave scratch or `.partial` publication files; remove
only those belonging to a stopped job. Failed-job logs persist until manually
removed. One advisory lock per user blocks overlapping jobs even with different
scratch directories; it does not coordinate other users or llama.cpp.

## Supported inputs and limitations

Version one deliberately accepts ordinary **opaque 8-bit SDR, progressive,
constant-frame-rate, square-pixel video with zero-based stream starts**. It rejects
VFR/discontinuous timestamps, HDR/wide-gamut signalling, 10-bit/alpha formats,
interlacing, rotation metadata, non-square pixels, and nonzero stream start times.
Normalize unsupported sources explicitly; the tool does not silently tone-map or
change timing. HDR without correct metadata cannot be detected reliably.

Only one non-attached video stream is supported. Only the first audio stream is
retained; subtitles, chapters, attachments, and source metadata are not preserved.
An unusually short source audio track remains short (no invented audio or padding).
Preview times are frame-aligned and seek from the source's zero-based timeline.
Timestamp verification scans the whole source even for a preview; expect an initial
CPU decode pass. Output validation is another decode pass.

Frame-by-frame restoration can cause shimmer and inconsistent skin/outline detail.
It cannot repair identity changes, malformed hands, or inconsistent motion. Judge
moving video, not just a sharp still frame. CPU encoding is intentional; hardware
encoding and GPU contention management are outside this first version.

## Validation

Implemented automated coverage uses real FFmpeg/Pillow and a mock **only** for the
GPU executable: both profiles, multiple chunks, fractional FPS, portrait sizing,
preview selection, audio duration, missing audio, unsupported formats, VFR, invalid
inputs, no-clobber publication, lock contention, failed subprocesses, and cleanup.
It does not establish actual model quality or RX 570 compatibility/performance.

Implementation checks: both complete NixOS configurations evaluated to derivations;
Home Manager enables the tool only on `home-server`; the packaged CLI builds; and
15 automated tests pass in the Nix sandbox. Existing Stylix/Zen Browser and Vicinae
evaluation warnings are unrelated to this module. No system configuration was activated.

From the repository root, run the reproducible test derivation using locked inputs:

```bash
hc run --bg 'nix build --impure --no-link --expr '\''
  let f = builtins.getFlake (toString ./nix/nixos);
      pkgs = f.inputs.nixpkgs.legacyPackages.x86_64-linux;
  in import ./nix/nixos/modules/home/programs/upscaling/video/tests { inherit pkgs; }
'\'''
```

For development with Python/Pillow and FFmpeg already available:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover \
  -s nix/nixos/modules/home/programs/upscaling/video/tests -v
```

`gpu-lease` (stop llama only if it was running, restore on failure, lock, VRAM gate):

```bash
hc run --bg 'nix build --impure --no-link --expr '\''
  let f = builtins.getFlake (toString ./nix/nixos);
      pkgs = f.inputs.nixpkgs.legacyPackages.x86_64-linux;
  in import ./nix/nixos/hosts/home-server/modules/ai/gpu-lease-tests.nix { inherit pkgs; }
'\'''
```

Before rebuilding from a Git-backed flake, ensure the new module files are included
in its source (Nix excludes untracked files). No deployment is performed by tests.

### RX 570 acceptance checklist — pending

No server deployment or RX 570 benchmark was performed during implementation.

- [ ] Deploy explicitly; verify Vulkan as `e`, then `gpu-lease -- true` and confirm llama-cpp returns.
- [ ] Choose one 3–5-second UGC clip and one representative cartoon clip.
- [ ] Generate matching AI/Lanczos previews and keep their JSON summaries.
- [ ] Watch each at normal speed for eye/teeth/skin artifacts and outline shimmer.
- [ ] Monitor `amdgpu_top`/`radeontop` separately for GPU memory and utilization.
- [ ] Record processing FPS, scratch usage, and peak VRAM; adjust tile/chunk settings.
- [ ] Confirm original audio stays synchronized and portrait orientation is correct.
- [ ] Restore inference to its original running/stopped state.

Keep defaults provisional until this checklist passes. Never extrapolate total-job
speed from model inference alone: scanning, chunk startup, resizing, encoding,
validation, and final file copying all contribute.
