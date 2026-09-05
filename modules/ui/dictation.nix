{
  flake.modules.nixos.dictation =
    {
      config,
      inputs,
      lib,
      pkgs,
      username,
      ...
    }:
    let
      whisperSmallEn = pkgs.fetchurl {
        url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin";
        hash = "sha256-xhONbVjsyDIgl+D5h8MvG+i7ChhTKj+I9zTRu/nEHl0=";
      };

      dictateToggle = pkgs.writeShellApplication {
        name = "dictate-toggle";
        runtimeInputs = with pkgs; [
          coreutils
          ffmpeg
          gawk
          gnugrep
          gnused
          libnotify
          procps
          util-linux
          whisper-cpp
          wl-clipboard
          xclip
          xsel
        ];
        text = ''
          export DICTATE_MODEL="''${DICTATE_MODEL:-${whisperSmallEn}}"
          ${lib.optionalString (config.dictation.pulseServer != null) ''
            export PULSE_SERVER=${lib.escapeShellArg config.dictation.pulseServer}
          ''}
        ''
        + builtins.readFile ./dictate-toggle.sh;
      };
    in
    {
      imports = [ inputs.nixos-pi.nixosModules.dictationExtension ];

      options.dictation.pulseServer = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "PulseAudio server used by the dictation recorder.";
      };

      config.home-manager.users.${username}.home.packages = [ dictateToggle ];
    };
}
