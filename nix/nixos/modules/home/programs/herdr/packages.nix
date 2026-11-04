{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  libxcb,
  libxkbcommon,
  libglvnd,
  vulkan-loader,
  wayland,
}:
let
  # wgpu and the Wayland backend dlopen these. They go on RUNPATH, not
  # LD_LIBRARY_PATH: herdr-core copies the app's environment into every
  # terminal it starts.
  dlopenLibs = [
    libglvnd
    vulkan-loader
    wayland
  ];
in
{
  herdr-core = stdenv.mkDerivation (finalAttrs: {
    pname = "herdr-core";
    version = "0.1.18";

    src = fetchurl {
      url = "https://releases.herdr.dev/core/${finalAttrs.version}/herdr-core-linux-x86_64.tar.gz";
      hash = "sha256-Wy+Xy0sqnXprLMWUJiggPtn7t8wMK0sJrYpvVkjiRrc=";
    };

    dontBuild = true;
    dontConfigure = true;

    # The release tarball has no top-level directory, which stdenv rejects.
    unpackPhase = ''
      runHook preUnpack
      mkdir source
      tar -xzf "$src" -C source
      cd source
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall
      install -Dm755 herdr-core $out/bin/herdr-core
      ln -s herdr-core $out/bin/hc
      install -Dm644 LICENSE THIRD-PARTY-NOTICES -t $out/share/licenses/herdr-core
      runHook postInstall
    '';

    doInstallCheck = true;
    installCheckPhase = ''
      $out/bin/hc --version | grep -F "0.1.18"
    '';

    meta = {
      description = "Headless terminal runtime for the Herdr desktop app";
      homepage = "https://herdr.dev/core/";
      license = lib.licenses.asl20;
      platforms = [ "x86_64-linux" ];
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
      mainProgram = "hc";
    };
  });

  herdr-app = stdenv.mkDerivation (finalAttrs: {
    pname = "herdr-app";
    version = "0.1.13";

    src = fetchurl {
      url = "https://releases.herdr.dev/app/${finalAttrs.version}/herdr-app-linux-x86_64.tar.gz";
      hash = "sha256-d7C+cqRsoUuzZzZaBBZGQfkUs6aXErrDkdOcVqlZvvQ=";
    };

    nativeBuildInputs = [ autoPatchelfHook ];
    buildInputs = [
      libxcb
      libxkbcommon
      stdenv.cc.cc.lib
    ];

    dontBuild = true;
    dontConfigure = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 herdr-app $out/bin/herdr-app
      install -Dm644 herdr-app.svg $out/share/icons/hicolor/scalable/apps/herdr-app.svg
      install -Dm644 LICENSE THIRD-PARTY-NOTICES -t $out/share/licenses/herdr-app
      runHook postInstall
    '';

    doInstallCheck = true;
    # autoPatchelf runs in postFixup and replaces RUNPATH. A custom
    # installCheckPhase does not run the preInstallCheck hook, so add the
    # dlopen libs here, after fixup.
    installCheckPhase = ''
      patchelf --add-rpath ${lib.makeLibraryPath dlopenLibs} $out/bin/herdr-app
      $out/bin/herdr-app --version | grep -F "0.1.13"
    '';

    meta = {
      description = "Herdr desktop app";
      homepage = "https://herdr.dev/";
      license = lib.licenses.asl20;
      platforms = [ "x86_64-linux" ];
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
      mainProgram = "herdr-app";
    };
  });

  collie = stdenv.mkDerivation (finalAttrs: {
    pname = "collie";
    version = "1.26.1";

    src = fetchurl {
      url = "https://github.com/AltanS/collie/releases/download/v${finalAttrs.version}/collie-${finalAttrs.version}-linux-x64.tar.gz";
      hash = "sha256-JNXBkHS1iCAj7xa67TffumFQnd+Ynj0tJm/ZtFtlvAw=";
    };

    nativeBuildInputs = [ autoPatchelfHook ];

    dontBuild = true;
    dontConfigure = true;
    # strip drops the Bun payload this binary dispatches commands from.
    dontStrip = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib $out/bin
      cp -a . $out/lib/collie
      chmod 755 $out/lib/collie/bin/collie
      ln -s $out/lib/collie/bin/collie $out/bin/collie
      runHook postInstall
    '';

    doInstallCheck = true;
    installCheckPhase = ''
      $out/bin/collie version | grep -F "1.26.1"
    '';

    meta = {
      description = "Phone client for Herdr and herdr-core, served on the tailnet";
      homepage = "https://github.com/AltanS/collie";
      license = lib.licenses.mit;
      platforms = [ "x86_64-linux" ];
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
      mainProgram = "collie";
    };
  });
}
