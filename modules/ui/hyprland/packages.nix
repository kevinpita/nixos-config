{
  flake.modules.nixos.hyprland =
    {
      pkgs,
      username,
      ...
    }:
    {
      home-manager.users.${username} = {
        home.packages = with pkgs; [
          wofi
          hyprshot
          brightnessctl
          playerctl
        ];
      };
    };
}
