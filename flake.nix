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

    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";

    nixos-hardware.url = "github:NixOS/nixos-hardware";

    nixos-grub-themes.url = "github:jeslie0/nixos-grub-themes";
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

        m710q = nixpkgs.lib.nixosSystem {
          inherit system pkgs;
          modules = [
            ./hosts/m710q
          ] ++ commonModules;
          specialArgs = {
            hostname = "m710q";
            gui = true;
            inherit inputs username;
          };
        };

        amdep = nixpkgs.lib.nixosSystem {
          inherit system pkgs;
          modules = [
            ./hosts/amdep
          ] ++ commonModules;
          specialArgs = {
            hostname = "amdep";
            gui = true;
            inherit inputs username;
          };
        };
      };

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-rfc-style;
    };
}
