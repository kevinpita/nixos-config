{ username, ... }:

{
  services.syncthing = {
    enable = true;
    user = username;
    dataDir = "/home/${username}/";
    configDir = "/home/${username}/Documents/.config/syncthing";
    overrideDevices = true;
    overrideFolders = true;
    settings = {
      devices = {
        "Pixel 5" = {
          id = "QEW4Z4J-EJE5RDC-UNKAH7Q-NBHVW4L-TAGE4R6-AHQKYWJ-R64A2RR-2ODRBAM";
        };
      };
      folders = {
        "afnt2-e5u36" = {
          path = "/home/${username}/keepass";
          devices = [ "Pixel 5" ];
        };
      };
    };
  };
}
