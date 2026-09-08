{
  flake.modules.nixos.hyprland =
    {
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
        ''
        + builtins.readFile ../../hyprland/dictate-toggle.sh;
      };
    in
    {
      home-manager.users.${username} = {
        home.packages = [ dictateToggle ];
        xdg.configFile."hypr/hyprland.lua".text = lib.mkAfter ''
          hl.bind("SUPER + G", hl.dsp.exec_cmd("${dictateToggle}/bin/dictate-toggle"))
        '';
      };
    };
}
