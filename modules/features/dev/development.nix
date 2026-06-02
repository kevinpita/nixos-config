{
  config,
  lib,
  pkgs,
  username,
  ...
}:
lib.mkIf config.features.development.enable {
  environment.systemPackages = with pkgs; [
    go
    gotest
    python3

    lazydocker
    lazysql
    mqttui
  ];

  home-manager.users.${username} = {
    home.packages =
      (with pkgs; [
        nixd
        nixfmt
      ])
      ++ lib.optionals config.features.desktop.enable (
        with pkgs;
        [
          jetbrains.datagrip
          jetbrains.goland
          jetbrains.idea
        ]
      );

    programs = {
      direnv = {
        enable = true;
        enableZshIntegration = true;
        nix-direnv.enable = true;
      };
    };
  };
}
