{ config, inputs, ... }:
{
  flake.overlays.default = final: _prev: {
    exrpd = final.callPackage ../packages/exrpd/package.nix { };
    inherit (inputs.herdr-nix.overlays.default final _prev) herdr herdr-core herdr-tui;
    herdr-auto-title = final.callPackage ../packages/herdr-auto-title/package.nix { };
    mcp-reva = final.callPackage ../packages/mcp-reva/package.nix { };
    open-code-review = final.callPackage ../packages/open-code-review/package.nix { };
    ovis = final.callPackage ../packages/ovis/package.nix { };
    plymouth-nixos-grub = final.callPackage ../packages/plymouth-nixos-grub/package.nix {
      grubTheme = inputs.nixos-grub-themes.packages.${final.stdenv.hostPlatform.system}.nixos;
    };
    prometheus-podman-exporter =
      final.callPackage ../packages/prometheus-podman-exporter/package.nix
        { };
    rea = final.callPackage ../packages/rea/package.nix { };
  };

  perSystem =
    { pkgs, ... }:
    {
      packages = config.flake.overlays.default pkgs pkgs;
    };
}
