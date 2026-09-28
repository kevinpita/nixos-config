{
  config,
  inputs,
  lib,
  ...
}:
let
  username = "kevin";
  tailnetDomain = "tail235c8.ts.net";
  system = "x86_64-linux";

  overlays = [
    inputs.claude-code.overlays.default

    inputs.codex-cli-nix.overlays.default

    (_final: _prev: {
      inherit (inputs.kevinpita-nixpkgs.legacyPackages.${system}) helm-tui;
      inherit (inputs.nixpkgs-pgbot.legacyPackages.${system}) pgbot;
    })

    inputs.herdr-nix.overlays.default

    inputs.bast-nix.overlays.default

    inputs.ku-nix.overlays.default

    inputs.lazyrsync-nix.overlays.default

    inputs.tuicr-nix.overlays.default

    inputs.ink-nix.overlays.default

    config.flake.overlays.default
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

  hostsWithRole =
    role:
    lib.attrNames (
      lib.filterAttrs (_: host: lib.elem role host.config.host.roles) config.flake.nixosConfigurations
    );

  rolesModule = {
    options.host.roles = lib.mkOption {
      type = lib.types.listOf (
        lib.types.enum [
          "desktop"
          "server"
          "workstation"
        ]
      );
      default = [ ];
      description = "Roles this host imports. Other hosts read them through hostsWithRole.";
    };
  };
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
          rolesModule
          inputs.disko.nixosModules.disko
          inputs.home-manager.nixosModules.home-manager
          config.flake.modules.nixos.neovim
          inputs.sops-nix.nixosModules.sops
        ];
        specialArgs = {
          inherit
            inputs
            username
            hostname
            hostsWithRole
            tailnetDomain
            ;
          inherit (privateInputs) ciMode workConfig;
        };
      }
    )
  ) hostModules;
}
