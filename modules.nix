{ inputs }:

{
  commonModules = [
    inputs.disko.nixosModules.disko
    inputs.home-manager.nixosModules.home-manager
  ];

  customModules = { hostname, modules }: [ ./hosts/${hostname}/configuration.nix ] ++ modules;
}
