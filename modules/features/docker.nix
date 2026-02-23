{
  config,
  lib,
  pkgs,
  username,
  ...
}:
lib.mkIf config.features.docker.enable {
  virtualisation.docker = {
    autoPrune.enable = true;
    enable = true;
    storageDriver = "btrfs";

    rootless = {
      enable = true;
      setSocketVariable = true;
    };
  };

  users.users.${username}.extraGroups = [ "docker" ];

  environment.systemPackages = with pkgs; [ docker-compose ];
}
