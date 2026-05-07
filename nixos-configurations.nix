{
  inputs,
  ...
}:
let
  username = "kevin";
  system = "x86_64-linux";

  overlays = [
    inputs.nix-vscode-extensions.overlays.default

    inputs.claude-code.overlays.default

    inputs.codex-cli-nix.overlays.default

    inputs.gemini-cli-nix.overlays.default

    # TODO: remove once helm-tui is merged into nixpkgs
    (_final: _prev: {
      inherit (inputs.kevinpita-nixpkgs.legacyPackages.${system}) helm-tui;
    })

    # TODO: remove once herdr is merged into nixpkgs
    (_final: _prev: {
      inherit (inputs.kevinpita-herdr-nixpkgs.legacyPackages.${system}) herdr;
    })
  ];

  pkgs = import inputs.nixpkgs {
    inherit system overlays;
    config.allowUnfree = true;
  };

  commonModules = [
    inputs.comin.nixosModules.comin
    inputs.disko.nixosModules.disko
    inputs.home-manager.nixosModules.home-manager
    inputs.nvim-config.nixosModules.neovim
    inputs.sops-nix.nixosModules.sops
    ./modules/core
    ./modules/features
  ];

  mkHost =
    {
      hostname,
      extraModules ? [ ],
    }:
    inputs.nixpkgs.lib.nixosSystem {
      inherit system pkgs;
      modules = [ ./hosts/${hostname} ] ++ commonModules ++ extraModules;
      specialArgs = {
        inherit inputs username hostname;
      };
    };
in
{
  flake.nixosConfigurations = {
    t480s = mkHost { hostname = "t480s"; };

    m710q = mkHost { hostname = "m710q"; };

    amdep = mkHost { hostname = "amdep"; };

    microg8 = mkHost { hostname = "microg8"; };
  };
}
