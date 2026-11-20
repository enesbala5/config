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

  # The tarball ships prebuilt, self-contained binaries. They must be kept
  # byte-for-byte identical:
  #   - The Tauri launcher SHA-256-checks lib/AliasMode/firefox/aliasmode at
  #     startup against its compiled-in build metadata. Rewriting its ELF
  #     (patchelf) changes those bytes and panics with
  #     "packaged AliasMode Firefox SHA-256 does not match build metadata".
  #   - aliasmode-sidecar and aliasmode-mcp are Bun-compiled executables whose
  #     embedded scripts live in the ELF; patchelf/strip truncate that payload
  #     and the sidecar dies with `Script not found "start"`.
  # So no autoPatchelfHook and no strip here. Instead nix-ld (enabled on this
  # host) loads the pristine binaries and the wrappers below supply their
  # shared libraries through NIX_LD_LIBRARY_PATH.
  runtimeLibs = with pkgs; [
    glib
    nss
    nspr
    at-spi2-core
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
    openssl
    libsoup_3
    gdk-pixbuf
  ];
  libPath = lib.concatStringsSep ":" (
    map (p: "${if p ? lib then p.lib else p.out}/lib") runtimeLibs
    ++ [ "${pkgs.stdenv.cc.cc.lib}/lib" ]
  );

  aliasmode = pkgs.stdenv.mkDerivation {
    pname = "aliasmode";
    inherit version src;
    nativeBuildInputs = [ pkgs.makeWrapper ];
    dontStrip = true;
    unpackPhase = ''
      tar -xzf $src
    '';
    installPhase = ''
      runHook preInstall

      # The tarball has no top-level binary or AppImage. Its layout is:
      #   AliasMode/bin/{aliasmode,aliasmode-sidecar,aliasmode-mcp}
      #   AliasMode/lib/AliasMode/{firefox,playwright,...}
      #   AliasMode/share/{applications,icons,...}
      # Mirror it under $out verbatim: the Tauri launcher resolves its bundled
      # Firefox/Playwright resources relative to itself (../lib/AliasMode), so
      # flattening the binary into $out/bin would leave it unable to find them.
      mkdir -p $out
      cp -a AliasMode/bin AliasMode/lib AliasMode/share $out/

      # Wrap each launcher with its runtime library path while leaving the
      # underlying ELF binaries untouched (see note above).
      for b in aliasmode aliasmode-sidecar aliasmode-mcp; do
        mv "$out/bin/$b" "$out/bin/$b.real"
        makeWrapper "$out/bin/$b.real" "$out/bin/$b" \
          --prefix NIX_LD_LIBRARY_PATH : "${libPath}"
      done

      runHook postInstall
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
    icon = "${aliasmode}/share/icons/hicolor/512x512/apps/aliasmode.png";
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
