{
  flake.modules.nixos.communication =
    {
      pkgs,
      username,
      ...
    }:
    {
      home-manager.users.${username} = {
        home.packages = with pkgs; [
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
          telegram-desktop
        ];

        xdg.mimeApps.defaultApplications = {
          "x-scheme-handler/tg" = "org.telegram.desktop.desktop";
          "x-scheme-handler/tonsite" = "org.telegram.desktop.desktop";
        };
      };
    };
}
