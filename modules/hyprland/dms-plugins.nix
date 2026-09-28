{
  flake.modules.nixos.hyprland =
    {
      config,
      lib,
      username,
      ...
    }:
    let
      cfg = config.programs.nixos-hyprland;
    in
    {
      options.programs.nixos-hyprland.dmsPlugins = lib.mkOption {
        type = lib.types.attrsOf lib.types.package;
        default = { };
        description = "DankMaterialShell plugins by directory name. DMS restarts when one changes.";
      };

      config.home-manager.users.${username} =
        { config, ... }:
        {
          xdg.configFile =
            lib.mapAttrs' (
              name: plugin: lib.nameValuePair "DankMaterialShell/plugins/${name}" { source = plugin; }
            ) cfg.dmsPlugins
            // {
              "DankMaterialShell/plugin_settings.json".source =
                config.lib.file.mkOutOfStoreSymlink "${cfg.configDirectory}/plugin_settings.json";
            };
          systemd.user.services.dms.Unit.X-Restart-Triggers = lib.attrValues cfg.dmsPlugins;
        };
    };
}
