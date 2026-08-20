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
      sessionCommand = "${lib.getExe config.programs.uwsm.package} start -e -D Hyprland hyprland.desktop";
      tuigreetCommand = lib.escapeShellArgs [
        (lib.getExe pkgs.tuigreet)
        "--time"
        "--remember"
        "--asterisks"
        "--cmd"
        sessionCommand
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
        settings = {
          default_session.command = tuigreetCommand;
          initial_session = {
            command = sessionCommand;
            user = username;
          };
        };
      };

      home-manager.users.${username} =
        { config, ... }:
        {
          xdg.configFile."hypr/hyprland.lua".source =
            config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/config/hypr/hyprland.lua";
        };
    };
}
