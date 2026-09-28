{
  flake.modules.nixos.hyprland =
    {
      pkgs,
      username,
      ...
    }:
    let
      piSessionsPlugin = pkgs.runCommand "pi-sessions-plugin" { } ''
        mkdir -p "$out"
        cp -a ${../../hyprland/plugins/piSessions}/. "$out/"
        substituteInPlace "$out/PiSessionsWidget.qml" \
          --replace-fail '@pi-session-status@' '${piSessionStatus}/bin/pi-session-status'
      '';
      piSessionStatus = pkgs.callPackage ../../packages/pi-session-status/package.nix { };
    in
    {
      programs.nixos-hyprland.dmsPlugins.piSessions = piSessionsPlugin;

      home-manager.users.${username} = {
        home.packages = [ piSessionStatus ];
      };
    };
}
