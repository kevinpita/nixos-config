{
  nixConfig = {
    extra-substituters = [
      "https://kevinpita.cachix.org"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "kevinpita.cachix.org-1:Cu9UtCDSfDq3/WDnI7N1N/LzAh90SPS+1R+nWao/hz0="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";

    import-tree.url = "github:vic/import-tree";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    autofirma-nix = {
      url = "github:nix-community/autofirma-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

    kevinpita-nixpkgs.url = "github:kevinpita/nixpkgs/helm-tui-init";

    herdr-nix.url = "github:kevinpita/herdr-nix";

    gh-stack = {
      url = "github:github/gh-stack";
      flake = false;
    };

    bast-nix.url = "github:kevinpita/bast-nix";

    whisp-nix.url = "github:kevinpita/whisp-nix";

    nixos-pi = {
      url = "github:kevinpita/nixos-pi";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    nixos-hyprland = {
      url = "github:kevinpita/nixos-hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    ku-nix.url = "github:kevinpita/ku-nix";

    lazyrsync-nix = {
      url = "github:kevinpita/lazyrsync-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    tuicr-nix = {
      url = "github:kevinpita/tuicr-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
