{
  username,
  ...
}:
{
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      ovmf.enable = true;
      runAsRoot = false;
    };
    onBoot = "ignore";
    onShutdown = "shutdown";
  };
  programs.dconf.enable = true;

  users.users.${username}.extraGroups = [
    "libvirtd"
    "kvm"
  ];

  boot = {
    extraModprobeConfig = "options kvm_intel nested=1";
    kernelModules = [ "kvm-intel" ];
    kernelParams = [ "intel_iommu=on" ];
  };
}
