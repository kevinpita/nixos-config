{
  username,
  ...
}:
{
  virtualisation.libvirtd.enable = true;
  programs.dconf.enable = true;

  users.users.${username}.extraGroups = [ "libvirtd" ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModprobeConfig = "options kvm_intel nested=1";
}
