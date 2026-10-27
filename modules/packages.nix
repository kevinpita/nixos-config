{ config, inputs, ... }:
{
  flake.overlays.default = final: _prev: {
    exrpd = final.callPackage ../packages/exrpd/package.nix { };
    # All Herdr callers use the same patched package.
    herdr = (final.callPackage "${inputs.herdr-nix}/package.nix" { }).overrideAttrs (old: {
      # Adds ui.focus_follows_mouse; drop once herdr ships it upstream.
      patches = (old.patches or [ ]) ++ [ ./base/herdr-focus-follows-mouse.patch ];
    });
    herdr-auto-title = final.callPackage ../packages/herdr-auto-title/package.nix { };
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
    { pkgs, ... }:
    {
      packages = config.flake.overlays.default pkgs pkgs;
    };
}
