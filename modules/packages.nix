{ config, inputs, ... }:
{
  flake.overlays.default = final: _prev: {
    exrpd = final.callPackage ../packages/exrpd/package.nix { };
    inherit (inputs.herdr-nix.overlays.default final _prev) herdr-core;
    # emoji.patch draws emoji in color and fits one-cell emoji to their cell.
    # agents-machine.patch keeps the remote machine name in the sidebar from
    # shrinking when a long agent name fills the row.
    # scrolled-back-clicks.patch sends a program that tracks the mouse no
    # clicks while the pane shows Herdr's scrollback, so a click on an old row
    # never lands on the live row under it.
    herdr = (inputs.herdr-nix.overlays.default final _prev).herdr.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        ./base/herdr-app/emoji.patch
        ./base/herdr-app/agents-machine.patch
        ./base/herdr-app/scrolled-back-clicks.patch
      ];
    });
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
