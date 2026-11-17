{
  config,
  lib,
  pkgs,
  unstable,
  ...
}:
let
  cfg = config.modules.home.easyeffects;

  # cab404/framework-dsp still ships EasyEffects ≤7 presets with kernel-path.
  # EE 8+ only accepts kernel-name (basename without .irs) under
  # $XDG_DATA_HOME/easyeffects/irs. See wwmm/easyeffects#4586.
  frameworkDsp = pkgs.stdenvNoCC.mkDerivation {
    pname = "framework-dsp-easyeffects";
    version = "unstable-2025-11-29";

    src = pkgs.fetchFromGitHub {
      owner = "cab404";
      repo = "framework-dsp";
      rev = "6e5b8e7a5d1f422bcaa2f237f28223fe2292ca38";
      hash = "sha256-nqAFmeDfEOMwZArs4AKo2ANzcOVEkEV4dqLqKYlu5tk=";
    };

    nativeBuildInputs = [ pkgs.jq ];

    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/easyeffects/{output,irs}
      cp -v config/irs/*.irs $out/share/easyeffects/irs/
      for f in config/output/*.json; do
        jq '
          walk(
            if type == "object" and has("kernel-path") then
              (.["kernel-path"] | split("/")[-1] | sub("\\.irs$"; "")) as $name
              | del(.["kernel-path"])
              | . + { "kernel-name": $name }
            else
              .
            end
          )
        ' "$f" > "$out/share/easyeffects/output/$(basename "$f")"
      done
      runHook postInstall
    '';
  };

  ensureAuto = pkgs.writeShellScript "ensure-easyeffects-auto" ''
    # EasyEffects must not be the default sink. It follows the hardware
    # default and pulls streams onto its virtual device when these keys are on.
    file="''${XDG_CONFIG_HOME:-$HOME/.config}/easyeffects/db/easyeffectsrc"
    mkdir -p "$(dirname "$file")"
    touch "$file"

    set_ini_key() {
      local section=$1 key=$2 value=$3
      local tmp
      tmp=$(mktemp)
      awk -v section="$section" -v key="$key" -v value="$value" '
        BEGIN { insec = 0; done = 0 }
        /^\[/ {
          if (insec && !done) {
            print key "=" value
            done = 1
          }
          insec = ($0 == "[" section "]")
        }
        insec && index($0, key "=") == 1 {
          print key "=" value
          done = 1
          next
        }
        { print }
        END {
          if (!done) {
            if (!insec) {
              if (NR > 0) print ""
              print "[" section "]"
            }
            print key "=" value
          }
        }
      ' "$file" >"$tmp" && mv "$tmp" "$file"
    }

    set_ini_key "EffectsPipelines" "processAllOutputs" "true"
    set_ini_key "StreamOutputs" "useDefaultOutputDevice" "true"
    set_ini_key "Presets" "lastLoadedOutputPreset" "${cfg.preset}"
    set_ini_key "Window" "outputAutoloadingFallbackPreset" "${cfg.preset}"
  '';
in
{
  options.modules.home.easyeffects = {
    enable = lib.mkEnableOption "EasyEffects with Framework DSP presets";

    package = lib.mkOption {
      type = lib.types.package;
      # nixos-26.05 is on 8.2.x; unstable tracks current releases.
      default = unstable.easyeffects;
      defaultText = lib.literalExpression "unstable.easyeffects";
      description = "EasyEffects package.";
    };

    preset = lib.mkOption {
      type = lib.types.str;
      default = "HifiScan+EEGuide";
      description = "Output preset loaded on service start (Framework DSP).";
    };

    frameworkDsp = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install cab404/framework-dsp presets and impulse responses, patched for EasyEffects 8+.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.easyeffects = {
      enable = true;
      package = cfg.package;
      preset = cfg.preset;
    };

    # Re-copy on each activation so kernel-name stays correct even if an older
    # local preset (kernel-path) was left behind from a manual framework-dsp
    # install. Files stay writable so EasyEffects can re-save them.
    home.activation.easyeffectsFrameworkDsp = lib.mkIf cfg.frameworkDsp (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        dataHome="''${XDG_DATA_HOME:-$HOME/.local/share}/easyeffects"
        mkdir -p "$dataHome/output" "$dataHome/irs"
        $DRY_RUN_CMD cp -f ${frameworkDsp}/share/easyeffects/output/*.json "$dataHome/output/"
        $DRY_RUN_CMD cp -f ${frameworkDsp}/share/easyeffects/irs/*.irs "$dataHome/irs/"
      ''
    );

    systemd.user.services.easyeffects.Service.ExecStartPre = "${ensureAuto}";
  };
}
