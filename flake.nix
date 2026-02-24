{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";

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

    treefmt-nix.url = "github:numtide/treefmt-nix";

    comin = {
      url = "github:nlewo/comin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-secrets = {
      url = "git+ssh://git@github.com/kevinpita/nixos-secrets";
      flake = false;
    };

    nixos-work = {
      url = "git+ssh://git@github.com/kevinpita/nixos-work";
      flake = false;
    };

    nixpkgs-claude-code = {
      url = "github:markus1189/nixpkgs/claude-code-2.1.50-to-2.1.52";
    };

    nixpkgs-sublime-merge = {
      url = "github:kevinpita/nixpkgs/sublime-merge-2123";
    };

  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];

      imports = [ ./nixos-configurations.nix ];

      perSystem =
        { pkgs, ... }:
        let
          treefmtEval = inputs.treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
        in
        {
          formatter = treefmtEval.config.build.wrapper;

          checks = {
            formatting = treefmtEval.config.build.check inputs.self;
          };
        };
    };
}
