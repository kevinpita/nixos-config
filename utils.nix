{
  inputs,
  lib,
  overlays,
}:
let
  commonModules = [
    inputs.disko.nixosModules.disko
    inputs.home-manager.nixosModules.home-manager
  ];

  mkCustomModules =
    {
      hostname,
      extraModules ? [ ],
    }:
    [ ./hosts/${hostname}/configuration.nix ] ++ extraModules;

  mkNixosSystem =
    {
      hostname,
      username,
      system,
      extraModules ? [ ],
    }:
    lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit inputs username hostname;
        pkgs = import inputs.nixpkgs {
          inherit system overlays;
          config = {
            allowUnfree = true;
          };
        };
      };
      modules =
        commonModules
        ++ mkCustomModules {
          inherit hostname;
          inherit extraModules;
        };
    };
in
{
  inherit mkNixosSystem;
}
