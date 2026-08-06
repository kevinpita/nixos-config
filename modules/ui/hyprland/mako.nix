{
  flake.modules.nixos.hyprland =
    { username, ... }:
    {
      home-manager.users.${username}.services = {
        hyprpolkitagent.enable = true;
        mako = {
          enable = true;
          settings = {
            anchor = "top-right";
            background-color = "#1e1e2e";
            border-color = "#89b4fa";
            border-radius = 10;
            border-size = 2;
            default-timeout = 5000;
            font = "JetBrainsMono Nerd Font 11";
            margin = 12;
            padding = 12;
            text-color = "#cdd6f4";
          };
        };
      };
    };
}
