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
      username = "kevin";
      system = "x86_64-linux";

      commonModules = [
        inputs.disko.nixosModules.disko
        inputs.home-manager.nixosModules.home-manager
      ];

      overlays = [ inputs.nix-vscode-extensions.overlays.default ];

      pkgs = import nixpkgs {
        inherit system overlays;
        config.allowUnfree = true;
      };

    in
    {
      nixosConfigurations = {
        t480 = nixpkgs.lib.nixosSystem {
          inherit system pkgs;
          modules = [
            ./hosts/t480
          ] ++ commonModules;
          specialArgs = {
            hostname = "t480";
            gui = true;
            inherit inputs username;
          };
        };
      };

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-rfc-style;
    };
}
