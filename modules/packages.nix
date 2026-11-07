{ config, inputs, ... }:
{
  flake.overlays.default = final: _prev: {
    claude-desktop = final.callPackage ../packages/claude-desktop/package.nix { };
    exrpd = final.callPackage ../packages/exrpd/package.nix { };
    mcp-reva = final.callPackage ../packages/mcp-reva/package.nix { };
    open-code-review = final.callPackage ../packages/open-code-review/package.nix { };
    plymouth-nixos-grub = final.callPackage ../packages/plymouth-nixos-grub/package.nix {
      grubTheme = inputs.nixos-grub-themes.packages.${final.stdenv.hostPlatform.system}.nixos;
    };
    prometheus-podman-exporter =
      final.callPackage ../packages/prometheus-podman-exporter/package.nix
        { };
    rea = final.callPackage ../packages/rea/package.nix { };
  };

  perSystem =
    { system, ... }:
    let
      # claude-desktop is unfree, so the default perSystem pkgs refuses to evaluate it.
      pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      packages = config.flake.overlays.default pkgs pkgs;
    };
}
