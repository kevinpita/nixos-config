{ config, inputs, ... }:
{
  flake.overlays.default = final: _prev: {
    exrpd = final.callPackage ../packages/exrpd/package.nix { };
    inherit (inputs.herdr-nix.overlays.default final _prev) herdr-core;
    # emoji.patch draws emoji in color and fits one-cell emoji to their cell.
    # agents-machine.patch truncates a long agent name in the sidebar so it
    # does not cover the remote machine name after it. dead-keys.patch stops
    # a Linux dead key from typing its US key, for example `[` for `^` on es.
    herdr = (inputs.herdr-nix.overlays.default final _prev).herdr.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        ./base/herdr-app/emoji.patch
        ./base/herdr-app/agents-machine.patch
        ./base/herdr-app/dead-keys.patch
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
