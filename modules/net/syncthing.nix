{
  flake.modules.nixos.syncthing =
    { username, ... }:
    {
      services.syncthing = {
        enable = true;
        user = username;
        dataDir = "/home/${username}/";
        configDir = "/home/${username}/.config/syncthing";
        overrideDevices = true;
        overrideFolders = true;
        settings = {
          devices = {
            "Pixel 10 Pro" = {
              id = "FV65C2K-IUTIX22-N7YONWB-CC3MQRK-PHJ44OZ-VHUWH3W-CO2B4M2-6EUBYA4";
              introducer = true;
            };
          };
          folders = {
            "afnt2-e5u36" = {
              label = "Keepass";
              path = "/home/${username}/keepass";
              devices = [ "Pixel 10 Pro" ];
            };
          };
        };
      };
    };

  # Both workstations additionally sync the Keepass folder with the work machine.
  flake.modules.nixos.workstation = {
    services.syncthing.settings = {
      devices."fium".id = "5MDWJ5N-EAY3RLI-BOKWRPA-SOVNZTM-FQRAPYW-CAH37PY-3ZP65ES-JKUXJQR";
      folders."afnt2-e5u36".devices = [ "fium" ];
    };
  };
}
