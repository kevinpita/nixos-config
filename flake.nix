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

    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
  };

  outputs =
    { nixpkgs, ... }@inputs:
    let

      overlays = [ inputs.nix-vscode-extensions.overlays.default ];

      utils = import ./utils.nix {
        inherit inputs overlays;
        inherit (nixpkgs) lib;
      };

      hosts = import ./hosts { inherit inputs nixpkgs utils; };
    in
    {
      inherit (hosts) formatter;
      inherit (hosts) nixosConfigurations;
    };
}
