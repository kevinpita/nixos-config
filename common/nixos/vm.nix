{
  username,
  ...
}:
{
  virtualisation.libvirtd.enable = true;
  programs.dconf.enable = true;

  users.users.${username}.extraGroups = [ "libvirtd" ];
  boot.extraModprobeConfig = "options kvm_intel nested=1";
  boot.kernelModules = [ "kvm-intel" ];
  boot.kernelParams = [ "intel_iommu=on" ];
}
