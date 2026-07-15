{
  config,
  inputs,
  lib,
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

    inputs.whisp-nix.overlays.default

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
        ghidraMcp = final.callPackage ../packages/ghidra-mcp { };
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

  hostModules = lib.filterAttrs (name: _: lib.hasPrefix "hosts/" name) config.flake.modules.nixos;
in
{
  flake.nixosConfigurations = lib.mapAttrs' (
    name: module:
    let
      hostname = lib.removePrefix "hosts/" name;
    in
    lib.nameValuePair hostname (
      inputs.nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        modules = [
          module
          inputs.disko.nixosModules.disko
          inputs.home-manager.nixosModules.home-manager
          inputs.nvim-config.nixosModules.neovim
          inputs.sops-nix.nixosModules.sops
        ];
        specialArgs = {
          inherit inputs username hostname;
        };
      }
    )
  ) hostModules;
}
