{
  flake.modules.nixos.development =
    {
      lib,
      pkgs,
      username,
      ...
    }:
    {
      environment.systemPackages = with pkgs; [
        # Build tools and language runtimes
        gnumake
        go
        gotest
        python3

        # Database and messaging clients
        lazysql
        mqttui
      ];

      home-manager.users.${username} = {
        home.packages = with pkgs; [
          # Nix language tools
          nixd
          nixfmt
        ];

        programs = {
          direnv = {
            enable = true;
            enableZshIntegration = false;
            nix-direnv.enable = true;
          };

          # Export the initial environment before Powerlevel10k's instant prompt,
          # then install the directory-change hook immediately afterward.
          zsh.initContent = lib.mkMerge [
            (lib.mkOrder 490 ''
              emulate zsh -c "$(${lib.getExe pkgs.direnv} export zsh)"
            '')
            (lib.mkOrder 505 ''
              emulate zsh -c "$(${lib.getExe pkgs.direnv} hook zsh)"
            '')
          ];
        };
      };
    };

  flake.modules.nixos.workstation =
    { pkgs, username, ... }:
    {
      home-manager.users.${username}.home.packages = with pkgs; [
        # Database clients
        jetbrains.datagrip

        # Integrated development environments
        arduino-ide
        jetbrains.goland
        jetbrains.idea
      ];
    };
}
