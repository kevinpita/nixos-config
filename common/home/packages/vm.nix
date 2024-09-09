{ pkgs, ... }:

{
  home.packages = with pkgs; [
    virt-manager
    virt-viewer
    qemu
    OVMF
    dnsmasq
    vde2
    bridge-utils
    netcat-openbsd
    libguestfs
    spice-gtk
    win-virtio
    swtpm
  ];

  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = [ "qemu:///system" ];
      uris = [ "qemu:///system" ];
    };
  };
}
