{
  inputs,
  nixpkgs,
  utils,
}:
let
  inherit (nixpkgs) lib;

  linux64 = "x86_64-linux";

  hosts = [
    {
      hostname = "t480";
      username = "kevin";
      system = linux64;
      extraModules = [ inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t480 ];
    }
  ];
in
{
  nixosConfigurations = lib.listToAttrs (
    map (host: {
      name = host.hostname;
      value = utils.mkNixosSystem {
        inherit (host)
          hostname
          system
          username
          extraModules
          ;
      };
    }) hosts
  );

  formatter = lib.listToAttrs (
    map (host: {
      name = host.system;
      value = nixpkgs.legacyPackages.${host.system}.nixfmt-rfc-style;
    }) hosts
  );
}
