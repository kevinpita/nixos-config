{
  nixConfig = {
    extra-substituters = [ "https://kevinpita.cachix.org" ];
    extra-trusted-public-keys = [
      "kevinpita.cachix.org-1:Cu9UtCDSfDq3/WDnI7N1N/LzAh90SPS+1R+nWao/hz0="
    ];
  };

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

    nixos-hardware.url = "github:kevinpita/nixos-hardware";

    nixos-grub-themes.url = "github:jeslie0/nixos-grub-themes";

    treefmt-nix.url = "github:numtide/treefmt-nix";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nvim-config = {
      url = "github:kevinpita/nixos-nvim";
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

    claude-code.url = "github:sadjow/claude-code-nix";

    codex-cli-nix.url = "github:sadjow/codex-cli-nix";

    codex-desktop-linux.url = "github:ilysenko/codex-desktop-linux";

    antigravity-nix.url = "github:jacopone/antigravity-nix";

    kevinpita-nixpkgs.url = "github:kevinpita/nixpkgs/helm-tui-init";

    herdr-nix.url = "github:kevinpita/herdr-nix";

    pi-flake = {
      url = "github:ChauDucToan/pi-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hunk = {
      url = "github:modem-dev/hunk";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ku-nix.url = "github:kevinpita/ku-nix";

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
