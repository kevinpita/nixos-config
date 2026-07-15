{
  flake.modules.nixos.development =
    {
      pkgs,
      username,
      ...
    }:
    {
      environment.systemPackages = with pkgs; [
        gnumake
        go
        gotest
        python3

        lazydocker
        lazysql
        mqttui
      ];

      home-manager.users.${username} = {
        home.packages = with pkgs; [
          nixd
          nixfmt
        ];

        programs = {
          direnv = {
            enable = true;
            enableZshIntegration = true;
            nix-direnv.enable = true;
          };
        };
      };
    };

  flake.modules.nixos."roles/desktop" =
    { pkgs, username, ... }:
    {
      home-manager.users.${username}.home.packages = with pkgs; [
        jetbrains.datagrip
        jetbrains.goland
        jetbrains.idea
      ];
    };
}
