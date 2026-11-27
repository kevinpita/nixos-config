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

    comin = {
      url = "github:nlewo/comin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dnie-nix = {
      url = "github:kevinpita/dnie-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:kevinpita/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-grub-themes = {
      url = "github:jeslie0/nixos-grub-themes";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    wrappers = {
      url = "github:BirdeeHub/nix-wrapper-modules";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plugins-lze = {
      url = "github:BirdeeHub/lze";
      flake = false;
    };

    plugins-lzextras = {
      url = "github:BirdeeHub/lzextras";
      flake = false;
    };

    nixos-secrets = {
      url = "git+ssh://git@github.com/kevinpita/nixos-secrets";
      flake = false;
    };

    nixos-work = {
      url = "git+ssh://git@github.com/kevinpita/nixos-work";
      flake = false;
    };

    kevinpita-nixpkgs.url = "github:kevinpita/nixpkgs/helm-tui-init";

    nixpkgs-pgbot.url = "github:kevinpita/nixpkgs/pgbot-init";

    herdr-nix = {
      url = "github:kevinpita/herdr-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    herdr-lazygit = {
      url = "github:kevinpita/herdr-lazygit";
      flake = false;
    };

    # Third-party mod, pinned to the audited commit. Review the diff before changing the revision.
    herdr-hoverfocus = {
      url = "github:monorkin/herdr-app-hoverfocus/1c8ca93f9758567b55694e22c243e36aea923e3d";
      flake = false;
    };

    bast-nix = {
      url = "github:kevinpita/bast-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # A release tag, because the prebuilt native addon in omp/natives.json
    # matches only the tagged source. omp-pin-release moves both together.
    oh-my-pi = {
      url = "github:can1357/oh-my-pi/v19.2.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pstack = {
      url = "github:michael-denyer/pstack-claude";
      flake = false;
    };

    impeccable = {
      url = "github:pbakaus/impeccable";
      flake = false;
    };

    mattpocock-skills = {
      url = "github:mattpocock/skills";
      flake = false;
    };

    cursor-plugins = {
      url = "github:cursor/plugins";
      flake = false;
    };

    obsidian-skills = {
      url = "github:obsidianmd/obsidian-skills";
      flake = false;
    };

    grafana-skills = {
      url = "github:grafana/skills";
      flake = false;
    };

    gh-stack-skills = {
      url = "github:github/gh-stack";
      flake = false;
    };

    awesome-copilot = {
      url = "github:github/awesome-copilot";
      flake = false;
    };

    unslop-ui = {
      url = "github:felipebasurto/unslop-ui";
      flake = false;
    };

    dankcalendar = {
      url = "github:AvengeMedia/dankcalendar";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dux-greeter = {
      url = "github:duxlabs-dev/dux-greeter";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ku-nix = {
      url = "github:kevinpita/ku-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lazyrsync-nix = {
      url = "github:kevinpita/lazyrsync-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ink-nix = {
      url = "github:kevinpita/ink-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    whisp-nix = {
      url = "github:kevinpita/whisp-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-desktop-nix = {
      url = "github:kevinpita/claude-desktop-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ilofan = {
      url = "github:kevinpita/ilofan";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    forklab = {
      url = "github:kevinpita/forklab";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
