{
  flake.modules.nixos.hyprland =
    {
      config,
      username,
      ...
    }:
    let
      cfg = config.programs.nixos-hyprland;
    in
    {
      home-manager.users.${username} =
        { config, ... }:
        {
          xdg.configFile."DankMaterialShell/plugin_settings.json".source =
            config.lib.file.mkOutOfStoreSymlink "${cfg.configDirectory}/plugin_settings.json";
        };
    };
}
