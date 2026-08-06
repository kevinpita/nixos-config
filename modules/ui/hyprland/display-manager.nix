{
  flake.modules.nixos.hyprland =
    { username, ... }:
    {
      programs.hyprland = {
        enable = true;
        xwayland.enable = true;
      };

      services.displayManager = {
        defaultSession = "hyprland";
        autoLogin = {
          enable = true;
          user = username;
        };
        sddm = {
          enable = true;
          wayland.enable = true;
        };
      };

      environment.sessionVariables.NIXOS_OZONE_WL = "1";
    };
}
