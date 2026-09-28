{
  flake.modules.nixos.hyprland.programs.nixos-hyprland.dmsPlugins.workspaceFinder = builtins.path {
    name = "workspace-finder-plugin";
    path = ../../hyprland/plugins/workspaceFinder;
  };
}
