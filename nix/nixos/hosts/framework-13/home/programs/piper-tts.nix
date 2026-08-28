# Piper TTS (local playback of the Wayland selection)
{
  pkgs,
  lib,
  config,
  data,
  ...
}:
let
  hf = "https://huggingface.co/rhasspy/piper-voices/resolve/main";
  fetchVoice = {
    name,
    path,
    onnxHash,
    jsonHash,
  }: {
    inherit name;
    onnx = pkgs.fetchurl {
      url = "${hf}/${path}/${name}.onnx";
      sha256 = onnxHash;
    };
    json = pkgs.fetchurl {
      url = "${hf}/${path}/${name}.onnx.json";
      sha256 = jsonHash;
    };
  };
  voices = [
    (fetchVoice {
      name = "en_US-amy-medium";
      path = "en/en_US/amy/medium";
      onnxHash = "063c43bbs0nb09f86l4avnf9mxah38b1h9ffl3kgpixqaxxy99mk";
      jsonHash = "0xvxjxk59byydx9gj6rdvvydp5zm8mzsrf9vyy6x6299sjs3x8lm";
    })
    (fetchVoice {
      name = "sq_AL-edon-medium";
      path = "sq/sq_AL/edon/medium";
      onnxHash = "1j2pki3zbc73d83zc16fivl45njcpi3szchp6n0wc2m06spyh2jx";
      jsonHash = "1xvh28nnkmfi9blawvfqq7vw0fh392xli52qr8mh9n2jxaz7gvp9";
    })
  ];
  voiceFiles = lib.listToAttrs (
    lib.concatMap (v: [
      {
        name = ".local/share/piper-voices/${v.name}.onnx";
        value = {
          source = v.onnx;
        };
      }
      {
        name = ".local/share/piper-voices/${v.name}.onnx.json";
        value = {
          source = v.json;
        };
      }
    ]) voices
  );
in
{
  home.packages = with pkgs; [
    # System `piper` is libratbag's mouse GUI; wrap TTS so the script can call
    # a name that does not collide.
    (writeShellScriptBin "piper-tts" ''
      exec ${lib.getExe piper-tts} "$@"
    '')
    mpv
    curl
  ];

  home.file = voiceFiles // {
    ".local/bin/hypr-piper-speak.sh" = {
      source = config.lib.file.mkOutOfStoreSymlink "${data.configDirectory}/scripts/audio/hypr-piper-speak.sh";
    };
  };
}
