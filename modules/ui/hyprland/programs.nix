{
  flake.modules.nixos.hyprland =
    {
      pkgs,
      username,
      ...
    }:
    {
      # Add programs that are only needed in the Hyprland desktop here.
      home-manager.users.${username}.home.packages = with pkgs; [
        brightnessctl
        cliphist
        grim
        networkmanagerapplet
        pavucontrol
        playerctl
        slurp
        wofi
      ];
    };
}
