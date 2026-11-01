{ inputs, ... }:
{
  flake.modules.nixos.hyprland =
    { config, username, ... }:
    {
      imports = [ inputs.dux-greeter.nixosModules.default ];

      programs.dms-greeter = {
        enable = true;
        compositor.name = "hyprland";
        configHome = config.users.users.${username}.home;
      };
    };
}
