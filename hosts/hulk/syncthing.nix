_: {
  services.syncthing = {
    guiAddress = "0.0.0.0:8384";
    settings = {
      devices = {
        "fium" = {
          id = "5MDWJ5N-EAY3RLI-BOKWRPA-SOVNZTM-FQRAPYW-CAH37PY-3ZP65ES-JKUXJQR";
        };
      };
      folders = {
        "afnt2-e5u36" = {
          devices = [ "fium" ];
        };
      };
    };
  };
}
