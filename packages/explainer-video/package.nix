{
  bash,
  bubblewrap,
  coreutils,
  fetchurl,
  ffmpeg-headless,
  linkFarm,
  manim,
  piper-tts,
  python3,
  writeShellApplication,
}:
let
  revision = "e9c8a39444359388adaa94255becb37a5a2b8e51";
  base = "https://huggingface.co/rhasspy/piper-voices/resolve/${revision}";
  voice =
    {
      dir,
      name,
      modelHash,
      configHash,
    }:
    linkFarm name [
      {
        name = "voice.onnx";
        path = fetchurl {
          url = "${base}/${dir}/${name}.onnx";
          hash = modelHash;
        };
      }
      {
        name = "voice.onnx.json";
        path = fetchurl {
          url = "${base}/${dir}/${name}.onnx.json";
          hash = configHash;
        };
      }
    ];
  spanish = voice {
    dir = "es/es_ES/davefx/medium";
    name = "es_ES-davefx-medium";
    modelHash = "sha256-0skiThIjIarDwzNDlX//TQ9GUibLdMZrD1IMo/jA3Qc=";
    configHash = "sha256-fYLQaezMoPh5Y70jwzFm/h720kprIxVDkxv+aSOX8lY=";
  };
  english = voice {
    dir = "en/en_US/ljspeech/medium";
    name = "en_US-ljspeech-medium";
    modelHash = "sha256-b1KnUeI0mr56dnNesJ3Bh1KYx36iNC/9L+95/4G4fyI=";
    configHash = "sha256-FB1hLMCpXtfvwcqTa4RcI2SWfy6SF8Xb/PafxNbGWGA=";
  };
  piper = piper-tts.override {
    withAlignment = false;
    withHTTP = false;
    withJapanese = false;
    withTrain = false;
  };
in
writeShellApplication {
  name = "explainer-video-env";
  runtimeInputs = [
    bash
    bubblewrap
    coreutils
    ffmpeg-headless
    manim
    piper
    python3
  ];
  inheritPath = false;
  text = ''
    export LC_ALL=C.UTF-8
    export EXPLAINER_VOICE_ES_ES=${spanish}/voice.onnx
    export EXPLAINER_VOICE_EN_US=${english}/voice.onnx
    exec bwrap --die-with-parent --unshare-net --bind / / --dev /dev -- "$@"
  '';
}
