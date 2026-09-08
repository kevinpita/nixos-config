{
  flake.modules.nixos.hyprland =
    {
      config,
      pkgs,
      username,
      ...
    }:
    let
      cfg = config.programs.nixos-hyprland;
    in
    {
      home-manager.users.${username} =
        { config, lib, ... }:
        {
          home.activation.dmsPluginState = lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] ''
            run ${pkgs.python3}/bin/python3 ${../../hyprland/migrate-plugin-state.py} \
              ${lib.escapeShellArg "${config.xdg.configHome}/DankMaterialShell/plugin_settings.json"} \
              ${lib.escapeShellArg "${config.xdg.stateHome}/DankMaterialShell/plugins"}
          '';

          xdg.configFile."DankMaterialShell/plugin_settings.json".source =
            config.lib.file.mkOutOfStoreSymlink "${cfg.configDirectory}/plugin_settings.json";
        };
    };
}
