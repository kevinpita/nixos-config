{
  inputs,
  ...
}:
let
  username = "kevin";
  system = "x86_64-linux";

  overlays = [
    inputs.nix-vscode-extensions.overlays.default

    (final: prev: {
      claude-code =
        let
          nixpkgs-claude-code-pkgs = import inputs.nixpkgs-claude-code {
            inherit system;
            config.allowUnfree = true;
          };
        in
        nixpkgs-claude-code-pkgs.claude-code;
    })

    (final: prev: {
      sublime-merge =
        let
          nixpkgs-sublime-merge-pkgs = import inputs.nixpkgs-sublime-merge {
            inherit system;
            config.allowUnfree = true;
          };
        in
        nixpkgs-sublime-merge-pkgs.sublime-merge;
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
    t480 = mkHost { hostname = "t480"; };

    t480s = mkHost { hostname = "t480s"; };

    m710q = mkHost { hostname = "m710q"; };

    amdep = mkHost { hostname = "amdep"; };

    microg8 = mkHost { hostname = "microg8"; };
  };
}
