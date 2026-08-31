{
  flake.modules.nixos.vmware = {
    virtualisation.vmware.host.enable = true;

    boot.kernelParams = [
      "kvm.enable_virt_at_load=0"
      "transparent_hugepage=never"
    ];
  };
}
