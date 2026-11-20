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
  status.json     { state, started_at, updated_at, [progress_done/total], [error] }
  outputs.json    paths matching --pull, written when CMD exits 0
  run.log         stdout + stderr of CMD
  exitcode        CMD's exit code
  pid             pid of the detached run.sh
```

A command runs with the job dir as its cwd, so `DIR` is `./src`, uploads are
`./in/<basename>`, and `OUT=../out` writes into the job's `out/`.

## CLI

```
render-remote run [--job ID] [--out DIR] [--gpu] [--no-wait]
                  [--progress GLOB:TOTAL] [--pull GLOB]... [--upload FILE]...
                  DIR -- CMD ARGS...
render-remote watch  JOB [--out DIR]
render-remote status JOB
render-remote pull   JOB [--out DIR]
```

`run` syncs first, then starts `render-worker` with `nohup setsid`, and polls
`status.json` every 10 s (`RENDER_REMOTE_POLL`). `--pull` matches are listed in
`outputs.json` only after CMD exits 0, and are then copied into `--out` by
basename. `watch` and `pull` can fetch them at that point, not incrementally
while the command is still running. The job survives a closed terminal or
sleeping laptop; `watch` re-attaches. `--out` is remembered per job under
`$XDG_STATE_HOME/render-remote/`. `--gpu` wraps the command in
`gpu-lease -- xvfb-run -a` — the same lease upscaling uses, so inference comes
back when the render ends.

`status` exits 0 when done, 1 on failure, 3 while still running. Re-running
with the same `--job` starts the command again unless every named `--pull`
output is already local, in which case the job is skipped entirely. Sync does
not use `--delete`, and a rerun does not clear the host `out/` directory, so
stale files can remain under `src/` and leftover frames can inflate `--progress`
until the command itself removes them.

Both `--progress` and `--pull` globs must have a fixed directory with the
wildcard only in the last component (`out/frames/*.png`), since expansion uses
`find -maxdepth 1`. Nix's bash has no `compgen`.

## Macbook composition

`scripts/utilities/render-macbook` is the thin call site for the Blender
MacBook composition:

```sh
render-macbook --look --at 4 /abs/screen.mp4                 # one still
render-macbook --config /abs/shot.json /abs/screen.mp4        # full mp4
render-macbook --engine CYCLES /abs/screen.mp4                # CPU path
```

It reads `scene.json` (and an optional config) for the frame count and engine,
uploads the recording/config, picks `--gpu` for EEVEE, and calls
`render-remote` with `make -C src ... OUT=../out`. Check a `--look` still
before the full render. Override the composition path with `MACBOOK_DIR`.

Frame-level resume is not implemented: the composition's `make render` starts
with `rm -rf out/frames`, so a failed mid-render restarts the frame loop. The
frames stay on the host for inspection.

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
