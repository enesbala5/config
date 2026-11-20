# AliasMode via their published Linux x64 tarball.
# Native binary; profiles and proxy assignment stay inside AliasMode.
# Agenix secret is available at runtime for future import scripts (PENDING).
{
  pkgs,
  lib,
  config,
  ...
}:
let
  version = "0.1.0-beta.75";
  # Hash from aliasmode.com download page (SHA-256 of the tarball).
  # Converted to SRI for fetchurl.
  src = pkgs.fetchurl {
    url = "https://github.com/aliasmode/aliasmode/releases/download/v${version}/AliasMode_${version}_x86_64-linux.tar.gz";
    hash = "sha256-fVCdABbcYLnRe+Lwdmi12haXbcnkCav/lS6Hn8Z5aYY=";
  };

  aliasmode = pkgs.stdenv.mkDerivation {
    pname = "aliasmode";
    inherit version src;
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = with pkgs; [
      # Common runtime libs for Electron/Tauri-style apps; adjust if needed.
      glib
      nss
      nspr
      at-spi2-atk
      cups
      dbus
      libdrm
      expat
      libxkbcommon
      pango
      cairo
      alsa-lib
      mesa
      libgbm
      libx11
      libxcb
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxrandr
      libxrender
      libxtst
      gtk3
      webkitgtk_4_1
    ];
    unpackPhase = ''
      tar -xzf $src
    '';
    installPhase = ''
      mkdir -p $out/bin $out/share/aliasmode
      # The tarball layout is expected to contain the AppImage or binary + resources.
      # Adjust paths after inspecting the archive if the first build fails.
      cp -r * $out/share/aliasmode/ || true
      if [ -f AliasMode ]; then
        install -m755 AliasMode $out/bin/aliasmode
      elif [ -f aliasmode ]; then
        install -m755 aliasmode $out/bin/aliasmode
      else
        # Fallback: look for an AppImage
        appimage=$(find . -name '*.AppImage' | head -1)
        if [ -n "$appimage" ]; then
          install -m755 "$appimage" $out/bin/aliasmode
        else
          echo "Could not locate AliasMode binary in tarball" >&2
          exit 1
        fi
      fi
    '';
    meta.mainProgram = "aliasmode";
  };
in
{
  home.packages = [ aliasmode ];

  xdg.desktopEntries.aliasmode = {
    name = "AliasMode";
    genericName = "Anti-Detect Browser";
    comment = "Open-source antidetect browser with AliasMode Firefox / Chromium engines";
    exec = "${lib.getExe aliasmode} %U";
    type = "Application";
    terminal = false;
    categories = [
      "Network"
      "WebBrowser"
    ];
  };

  # PENDING: bulk proxy import script that reads
  # ${config.age.secrets."proxies-us".path}
  # and feeds AliasMode's Local API or import format.
  # AliasMode exposes Local API + MCP.
}
