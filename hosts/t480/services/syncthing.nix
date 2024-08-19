{ username, ... }:

{
  imports = [ (import ../../../common/nixos/services/syncthing.nix { inherit username; }) ];

  services.syncthing = {
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
