{
  config,
  lib,
  pkgs,
  username,
  ...
}:
lib.mkIf config.features.communication.enable {
  home-manager.users.${username} = {
    home.packages = with pkgs; [
      legcord
      telegram-desktop
      (symlinkJoin {
        name = "slack";
        paths = [ slack ];
        buildInputs = [ makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/slack \
            --add-flags "--ozone-platform-hint=auto" \
            --add-flags "--enable-features=WaylandWindowDecorations,WebRTCPipeWireCapturer"
        '';
      })

      bruno
      keepassxc
      qbittorrent
      arduino-ide
    ];
  };
}
