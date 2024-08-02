{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware";
  };
  outputs =
    { nixpkgs, ... }@inputs:
    let
      hosts = import ./hosts {
        inherit inputs;
        inherit nixpkgs;
      };
    in
    {
      inherit (hosts) formatter;
      inherit (hosts) nixosConfigurations;
    };
}
