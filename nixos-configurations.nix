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

    (_final: _prev: {
      inherit (inputs.codex-desktop-linux.packages.${system}) codex-desktop;
    })

    inputs.antigravity-nix.overlays.default

    (_final: _prev: {
      inherit (inputs.kevinpita-nixpkgs.legacyPackages.${system}) helm-tui;
    })

    (_final: _prev: {
      herdr = inputs.herdr-nix.packages.${system}.default;
    })

    (_final: _prev: {
      orca-app = inputs.orca-nix.packages.${system}.default;
    })

    (_final: _prev: {
      ku = inputs.ku-nix.packages.${system}.default;
    })

    (
      final: _prev:
      let
        ghidraMcp = final.callPackage ./packages/ghidra-mcp { };
      in
      {
        ghidra-mcp = ghidraMcp;
        ghidra-mcp-bridge = ghidraMcp.bridge;
        ghidra-mcp-extension = ghidraMcp.extension;
      }
    )
  ];

  pkgs = import inputs.nixpkgs {
    inherit system overlays;
    config.allowUnfree = true;
  };

  commonModules = [
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
    amdep = mkHost { hostname = "amdep"; };
    hulk = mkHost { hostname = "hulk"; };
    microg8 = mkHost { hostname = "microg8"; };
    t14g6 = mkHost { hostname = "t14g6"; };
    t480s = mkHost { hostname = "t480s"; };
  };
}
