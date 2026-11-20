---
name: upscale-video
description: Raise the resolution of existing video clips (for example 720p to 1080p) by running the free GPU upscaler on home-server from the laptop with `upscale-remote` (ssh + rsync). Use when the user asks to upscale, enlarge, or sharpen footage and home-server is the provider. Covers the remote-host approval gate, running and resuming a batch, and checking the output. Does not generate missing shots or edit project files.
---

# Upscale video on home-server

Take clips that already exist and produce larger copies using the GPU on
`home-server`. The client is `upscale-remote`, defined in the config repo
(`nix/nixos/modules/home/programs/upscaling/`, see its `README.md`). The server
side is `upscale-video` run under `gpu-lease`. This skill covers only that run
and its check. A project may add its own rules on top (budget ledger, approvals,
where clips live); follow those first.

## Prerequisites

- `command -v upscale-remote` succeeds. It is installed by
  `modules.home.upscaling.remote.enable` (on in `framework-13`). If it is
  missing, report that and stop. Do not install it, and do not change anything on
  the remote host.
- The clips are `.mp4` files you can list by path.

## 1. Gate: remote host

`upscale-remote` runs `ssh` and `rsync` against another machine. Run it only when
the user explicitly asks for it **in the current turn**. An earlier yes, or the
existence of this skill, is not permission. Ask, wait for a yes, then run only
what was approved.

Say this before starting: the batch occupies the home-server GPU and stops the
local inference endpoint (`http://home-server:8080/v1`) until it ends. Do not use
that endpoint for other work meanwhile.

Reading local files, `command -v`, and `upscale-remote --help` need no approval.
`run`, `watch`, `status`, and `pull` all reach the host and do.

## 2. Run

List exactly the files to upscale; nothing is picked up implicitly:

```sh
upscale-remote run [--profile ugc] [--job <id>] [--out DIR] clip-1.mp4 clip-2.mp4
```

- `--job`: lowercase kebab-case id, unique per batch (default: first file name
  plus a timestamp). It names the server work dir `~/upscale-jobs/<job>`. Reuse
  the same id to resume.
- `--profile`: passed to `upscale-video`; the server validates it. Take valid
  names and output size from the config README. Do not guess.
- `--out`: where results go. Default is `upscaled/` beside the first input.
- It refuses to start if `amdgpu.gpu_recovery` is not `1` on the server, or if
  that job id is already running.
- It uploads, starts the batch detached, prints a line whenever progress
  changes, and copies each finished clip back as it completes. Exit `0`: every
  clip done and copied. Exit `1`: a clip failed; finished clips are already
  copied and the message names the failed one.
- Clips whose `<name>.mp4` is already in the output directory are left out, so a
  rerun with the same command resumes.

The batch keeps running if the terminal or laptop stops. Re-attach or inspect:

```sh
upscale-remote watch <job>     # progress, copying as clips finish
upscale-remote status <job>    # one-shot; exit 0 done, 1 failed, 3 running
upscale-remote pull <job>      # copy finished clips, do not wait
```

Run a long batch as a background task that keeps its log (for example
`hc run --bg 'upscale-remote run …'`, or `nohup … > log &`), not a foreground
wait. Its output is the progress log.

## 3. Verify

Originals are never modified. Check every output before anything uses it:

```sh
ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height,r_frame_rate:format=duration \
  -of default=nw=1 <clip>
```

Compare with the source: aspect ratio unchanged, duration within one frame, frame
rate unchanged, no stuck or truncated tail. Then look at it: upscalers can smear
skin or text, so a person approves the picture. The tool keeps the first audio
stream; if a project has an audio master, attach that, not the output's audio.

## Failure handling

- Report the exact error from `upscale-remote`. Do not retry in a loop.
- A failed clip: fix the cause, rerun the same command with the same `--job`.
- A dropped connection is retried for a while, then it exits with the re-attach
  command. The job keeps running on the server.
- If inference does not come back after a hard kill, the user restarts it with
  `sudo systemctl start llama-cpp.service` on home-server. Do not do that for them.
