# Remote render jobs

Generic delegation of "render this directory on the other machine". It knows
nothing about Blender or any particular composition: the caller supplies the
command, an optional progress glob and the output globs.

- `render-worker` runs on the render host (`home-server`) inside a job dir.
- `render-remote` runs on the workstation (`framework-13`) and drives it over
  ssh + rsync.

Both reach the other machine over ssh. Only start a job when the user asked for
it in the current turn.

## Enable

The shared `programs/default.nix` imports this module. Everything is disabled
by default:

```nix
# hosts/home-server/home/default.nix
modules.home.remoteRender = {
  enable = true;
  server.enable = true;
};

# hosts/framework-13/home/programs/default.nix
modules.home.remoteRender = {
  enable = true;
  remote.enable = true;
};
```

Enabling the server also installs `blender` (5.1.1 in the locked nixpkgs),
`ffmpeg`, `jq` and Xvfb. Override `modules.home.remoteRender.server.blenderPackage`
when a composition needs another version. `remote.host` and `remote.remoteRoot`
(defaults `home-server` and `render-jobs`) are configurable from the client
module.

## Job layout

```
~/render-jobs/<job>/
  src/            synced directory (out/ and .git/ are excluded)
  in/             extra files from --upload, by basename
  out/            where CMD should write results
  status.json     { state, started_at, updated_at, [progress_done/total],
                    [exit_code, pulled, pull_total, error] }
  outputs.json    paths matching --pull, written when CMD finishes
  run.log         stdout + stderr of CMD
  exitcode        worker's exit code (1 when a zero-exit CMD breaks the contract)
  pid             pid of the detached run.sh
```

A command runs with the **job root** as its cwd, so `DIR` is `./src`, uploads
are `./in/<basename>`, and results must be written to `./out`. `OUT=../out` is
only correct for `make -C src` (make changes into `src` first); from the job
root `../out` is outside the job and is never pulled. A direct command uses
`-P src/blender/main.py -- --out out ...`, not `-P blender/main.py -- --out ../out`.

## CLI

```
render-remote run [--job ID] [--out DIR] [--gpu] [--gpu-no-lease]
                  [--no-wait] [--no-sync]
                  [--progress GLOB:TOTAL] [--pull GLOB]... [--upload FILE]...
                  DIR -- CMD ARGS...
render-remote watch  JOB [--out DIR]
render-remote status JOB
render-remote pull   JOB [--out DIR]
render-remote logs   JOB
```

`run` syncs first, then starts `render-worker` with `nohup setsid`, and polls
`status.json` every 10 s (`RENDER_REMOTE_POLL`). `--pull` matches are listed in
`outputs.json` when CMD finishes and are then copied into `--out` by basename.
`watch` and `pull` can fetch them at that point, not incrementally while the
command is still running. The job survives a closed terminal or sleeping
laptop; `watch` re-attaches. `--out` is remembered per job under
`$XDG_STATE_HOME/render-remote/`. `status`/`pull` retry a transient ssh reset
twice; `watch` keeps retrying up to `RENDER_REMOTE_MAX_UNREACHABLE` times.

A command that exits 0 but does not reach `--progress TOTAL` or produces no
`--pull` output is recorded as `failed` (with the real `exit_code` in
`status.json`), not as `done`; the client checks the same contract on `done`,
so a Blender `OSError` that still exits 0 cannot be reported as success.
`status.json.error` keeps the matching error lines from the whole `run.log`
plus its tail; `render-remote logs JOB` prints the full log.

`--gpu` wraps the command in `gpu-lease -- xvfb-run -a` — the same lease
upscaling uses, so inference comes back when the render ends. `gpu-lease`
**stops `llama-cpp.service`** for the duration and in-flight `/v1` requests
will fail; the client warns when it starts such a job. `--gpu-no-lease` uses
`xvfb-run -a` alone when the side effect is not wanted.

Known bad combination: Blender 5.1.1 under `xvfb-run` on `home-server`
segfaults while building the MacBook scene (`/tmp/blender.crash.txt`). Its
backtrace ends in Mesa 26.1.8's `driCreateContextAttribs` via GLX, with LLVM 19
(`libclang-cpp`) and LLVM 21 (`libLLVM`) loaded in the same process — a driver
context-creation crash, not a render failure. That composition renders headless
in ~3.4 s/frame, so do not use `--gpu` for it until the Mesa/LLVM mismatch is
fixed.

`status` exits 0 when done, 1 on failure, 3 while still running. Re-running
with the same `--job` starts the command again unless every named `--pull`
output is already local, in which case the job is skipped entirely. Sync does
not use `--delete`, and a rerun does not clear the host `out/` directory, so
stale files can remain under `src/` and leftover frames can inflate `--progress`
until the command itself removes them. Reusing the id also makes rsync
incremental: the first run uploads the full composition, later runs only send
changes. For a large, unchanged composition, `--no-sync` skips the sync
entirely and uploads only the files named with `--upload` (recording, config).
It refuses a job whose `src/` has not been staged yet.

Both `--progress` and `--pull` globs must have a fixed directory with the
wildcard only in the last component (`out/frames/*.png`), since expansion uses
`find -maxdepth 1`. Nix's bash has no `compgen`.

## Macbook composition

`scripts/utilities/render-macbook` is the thin call site for the Blender
MacBook composition:

```sh
render-macbook --look --at 4 /abs/screen.mp4                  # one still
render-macbook --config /abs/shot.json /abs/screen.mp4         # full mp4
render-macbook --engine CYCLES /abs/screen.mp4                 # CPU path
render-macbook --job macbook --no-sync --start 81 --end 90 \
  --config /abs/shot.json /abs/screen.mp4                      # re-bake frames
```

It reads `scene.json` (and an optional config) for the frame count and engine,
uploads the recording/config, and calls `render-remote` with
`make -C src ... OUT=../out`. Check a `--look` still before the full render.
Override the composition path with `MACBOOK_DIR`. Headless is the default:
Blender 5.1.1 segfaults under `xvfb-run` on this scene, and `--gpu` would also
stop `llama-cpp.service`. `--gpu` remains as an explicit opt-in with a warning.

`--start`/`--end` call the composition's `make frames` target and pull back the
re-baked frames; `make render` itself starts with `rm -rf out/frames`, so a
failed full render restarts the frame loop. The frames stay on the host for
inspection. Keep the staged job id and use `--no-sync` for repeated shots to
avoid uploading the ~53 MB of room assets each time.

## Tests

Against a fake server (`ssh` runs the remote side locally; rsync is real):

```bash
bash nix/nixos/modules/home/programs/remote-render/remote/tests/test-render-remote.sh
```

Or reproducibly with locked inputs:

```bash
nix build --impure --no-link --expr \
  'let f = builtins.getFlake (toString ./nix/nixos); in import ./nix/nixos/modules/home/programs/remote-render/remote/tests { pkgs = f.inputs.nixpkgs.legacyPackages.x86_64-linux; }'
```
