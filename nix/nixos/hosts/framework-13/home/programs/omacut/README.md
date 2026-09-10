# Omacut for Nix

This is a flake for [omacut](https://github.com/omacom-io/omacut) — a dead-simple Qt Quick video **length** trimmer. Open a video, drag the yellow handles to pick a start and end, preview, and export as MP4.

Upstream builds with `qmake6` (not cmake). This flake mirrors that: it builds from source with Qt6 (`qtbase`, `qtdeclarative`, `qtmultimedia`), wraps the binary with `wrapQtAppsHook`, and puts `ffmpeg` / `ffprobe` plus `xdg-desktop-portal` on `PATH` so the runtime file picker and cut pipeline work out of the box. The desktop entry and scalable icon from upstream’s `pkgbuild/` are installed into the usual FHS locations under `$out/share`.

To use, add it to the relevant NixOS configuration flake inputs:

```nix
inputs = {
  # ...
  omacut.url = "github:OWNER/omacut-nix";

  # optional, but recommended if you closely follow NixOS unstable so it shares
  # system libraries (especially Qt)
  # NOTE: if you experience a build failure with omacut, the first thing to check is to remove this line!
  omacut.inputs.nixpkgs.follows = "nixpkgs";
  # ...
};
```

Replace `OWNER/omacut-nix` with the published repository path.

## Packages

This flake provides a single package, also exposed as `default`, for both `x86_64-linux` and `aarch64-linux`:

```
packages
├───aarch64-linux
│   └───default: package 'omacut'
└───x86_64-linux
    └───default: package 'omacut'
```

An `apps.default` entry is also provided so you can run it with `nix run`.

## Installation

The easiest way is to use the CLI imperatively:

```sh
nix profile install github:OWNER/omacut-nix
```

Or try it without installing:

```sh
nix run github:OWNER/omacut-nix
```

If you're on NixOS and/or home-manager, you should install it in your system or home configuration.

For example, in `configuration.nix` / a home-manager module:

```nix
environment.systemPackages = [
  inputs.omacut.packages.${pkgs.stdenv.hostPlatform.system}.default
];
```

Or with home-manager:

```nix
home.packages = [
  inputs.omacut.packages.${pkgs.stdenv.hostPlatform.system}.default
];
```

A binary called `omacut` is provided, plus a desktop file and icon that should show up in app launchers.

## FAQ

> Why does the wrapper include `xdg-desktop-portal`?

Omacut opens files through the XDG desktop portal (D-Bus), not a Qt file dialog alone. You still need a portal *backend* on the host (e.g. `xdg-desktop-portal-gtk` / `xdg-desktop-portal-hyprland` / `xdg-desktop-portal-kde`) — NixOS usually already has one for your desktop. The wrapper only ensures the portal client tooling is visible where the app expects it, alongside `ffmpeg` / `ffprobe`.

> Build is slow / Qt is duplicated?

You probably aren't overriding the `nixpkgs` input, so the flake pulls its own copy of Qt. Set:

```nix
omacut.inputs.nixpkgs.follows = "nixpkgs";
```

(or `nixpkgs-unstable`, matching whatever you use for Qt apps).

> How do I bump the upstream source?

Edit `rev` and `hash` in [`flake.nix`](./flake.nix). To get a new hash after changing `rev`:

```sh
# set hash = lib.fakeHash (or leave a wrong hash), then:
nix build
# copy the reported got: sha256-... into hash
```

Or prefetch:

```sh
nix store prefetch-file --unpack \
  "https://github.com/omacom-io/omacut/archive/<REV>.tar.gz"
```

## Caveats

- **Linux only.** Upstream targets Linux; this flake does not attempt Darwin or Windows.
- **Portal backend required** for the file picker on a locked-down Wayland session. The package does not install a compositor-specific portal implementation.
- **Pinned to a commit**, not a floating `master` ref, so updates are intentional. Upstream versioning in their Arch `PKGBUILD` may lag the git tip.
- As with other GPU/Qt apps, if you install outside NixOS (or without following your system `nixpkgs`), you may need [nix-community/nixGL](https://github.com/nix-community/nixGL) for acceleration.

## License

[omacut](https://github.com/omacom-io/omacut) itself is MIT licensed by its upstream authors.

The Nix packaging in this repository is also MIT.
