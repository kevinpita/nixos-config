{
  flake.modules.nixos.hyprland =
    {
      config,
      lib,
      pkgs,
      username,
      ...
    }:
    let
      tuigreetCommand = lib.escapeShellArgs [
        (lib.getExe pkgs.tuigreet)
        "--time"
        "--remember"
        "--asterisks"
        "--cmd"
        "${lib.getExe config.programs.uwsm.package} start -e -D Hyprland hyprland.desktop"
      ];
    in
    {
      programs.hyprland = {
        enable = true;
        withUWSM = true;
      };

      services.greetd = {
        enable = true;
        useTextGreeter = true;
        settings.default_session.command = tuigreetCommand;
      };

      home-manager.users.${username} =
        { config, ... }:
        {
          xdg.configFile."hypr/hyprland.lua".source =
            config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/config/hypr/hyprland.lua";
        };
    };
}
