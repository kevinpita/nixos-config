{ inputs, nixpkgs }:
let
  inherit (nixpkgs) lib;
  myLib = import ../lib.nix {
    inherit lib;
    inherit inputs;
  };

  linux64 = "x86_64-linux";

  hosts = [
    {
      hostname = "t480";
      username = "kevin";
      system = linux64;
      modules = [ inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t480 ];
    }
  ];
in
{
  nixosConfigurations = lib.listToAttrs (
    map (host: {
      name = host.hostname;
      value = myLib.createNixosConfig host;
    }) hosts
  );

  formatter = lib.listToAttrs (
    map (host: {
      name = host.system;
      value = nixpkgs.legacyPackages.${host.system}.nixfmt-rfc-style;
    }) hosts
  );
}
