{
  config,
  inputs,
  lib,
  ...
}:
let
  username = "kevin";
  system = "x86_64-linux";

  defaultPackageOverlay = name: input: _final: _prev: { ${name} = input.packages.${system}.default; };

  overlays = [
    inputs.claude-code.overlays.default

    inputs.codex-cli-nix.overlays.default

    (_final: _prev: {
      inherit (inputs.kevinpita-nixpkgs.legacyPackages.${system}) helm-tui;
      inherit (inputs.nixpkgs-pgbot.legacyPackages.${system}) pgbot;
    })

    (defaultPackageOverlay "herdr" inputs.herdr-nix)

    (defaultPackageOverlay "bast" inputs.bast-nix)

    (defaultPackageOverlay "ku" inputs.ku-nix)

    inputs.lazyrsync-nix.overlays.default

    inputs.tuicr-nix.overlays.default
  ];

  pkgs = import inputs.nixpkgs {
    inherit system overlays;
    config.allowUnfree = true;
  };

  privateInputs = import ../lib/private-inputs.nix {
    secrets = inputs.nixos-secrets;
    work = inputs.nixos-work;
    inherit username;
  };

  hostModules = lib.filterAttrs (name: _: lib.hasPrefix "hosts/" name) config.flake.modules.nixos;
in
{
  imports = [ inputs.flake-parts.flakeModules.modules ];

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
          config.flake.modules.nixos.neovim
          inputs.sops-nix.nixosModules.sops
        ];
        specialArgs = {
          inherit inputs username hostname;
          inherit (privateInputs) ciMode workConfig;
        };
      }
    )
  ) hostModules;
}
