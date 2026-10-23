{
  flake.modules.nixos.vmware =
    { lib, ... }:
    {
      virtualisation.vmware.host.enable = true;

      # The vmware Makefile copies the modules without the kernel signing step.
      # The module aggregator needs a kmodigest certificate for each external module.
      # Sign after fixup because the strip step removes appended signatures.
      nixpkgs.overlays = [
        (
          _: prev:
          lib.genAttrs [ "linuxPackages" "linuxPackages_latest" ] (
            name:
            prev.${name}.extend (
              _: kprev: {
                vmware = kprev.vmware.overrideAttrs (old: {
                  nativeBuildInputs = old.nativeBuildInputs ++ [ prev.buildPackages.kmodigest ];
                  postFixup = (old.postFixup or "") + ''
                    for module in "$out/lib/modules/${kprev.kernel.modDirVersion}/misc/"*.ko; do
                      kmodigest "$module"
                    done
                  '';
                });
              }
            )
          )
        )
      ];

      boot.kernelParams = [
        "kvm.enable_virt_at_load=0"
        "transparent_hugepage=never"
      ];
    };
}
