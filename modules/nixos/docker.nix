{ username, ... }:
{
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
}
