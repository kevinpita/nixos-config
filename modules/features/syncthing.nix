# Syncthing feature - File synchronization
{
  config,
  lib,
  username,
  ...
}:
lib.mkIf config.features.syncthing.enable {
  services.syncthing = {
    enable = true;
    user = username;
    dataDir = "/home/${username}/";
    configDir = "/home/${username}/Documents/.config/syncthing";
    overrideDevices = true;
    overrideFolders = true;
    settings = {
      devices = {
        "Pixel 9 Pro" = {
          id = "I5B22T5-HRH2QH2-KX2VJAN-EYCKD26-GS5HVRM-S2VCCES-ALQ22VV-B7JN4QC";
          introducer = true;
        };
      };
      folders = {
        "afnt2-e5u36" = {
          label = "Keepass";
          path = "/home/${username}/keepass";
          devices = [ "Pixel 9 Pro" ];
        };
      };
    };
  };
}
