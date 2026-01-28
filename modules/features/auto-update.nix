# Auto-update feature - comin for automatic configuration updates
{ config, lib, ... }:
lib.mkIf config.features.auto-update.enable {
  services.comin = {
    enable = true;
    remotes = [
      {
        name = "origin";
        url = "https://github.com/kevinpita/nixos-config.git";
        branches.main.name = "main";
      }
    ];
  };
}
