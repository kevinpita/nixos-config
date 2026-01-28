# Virtualization feature - Docker, libvirt, virt-manager
{
  config,
  lib,
  pkgs,
  username,
  ...
}:
lib.mkIf config.features.virtualization.enable {
  # Docker
  virtualisation.docker = {
    autoPrune.enable = true;
    enable = true;
    storageDriver = "btrfs";

    rootless = {
      enable = true;
      setSocketVariable = true;
    };
  };

  # libvirtd (KVM/QEMU)
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
    };
    onBoot = "ignore";
    onShutdown = "shutdown";
  };
  programs.dconf.enable = true;

  # User groups
  users.users.${username}.extraGroups = [
    "docker"
    "libvirtd"
    "kvm"
  ];

  # System packages for virtualization
  environment.systemPackages = with pkgs; [
    qemu
    OVMF
    dnsmasq
    vde2
    bridge-utils
    netcat-openbsd
    libguestfs
    spice-gtk
    virtio-win
    swtpm
  ];

  # Home Manager: Virt-manager
  home-manager.users.${username} = {
    home.packages = with pkgs; [
      virt-manager
      virt-viewer
    ];

    dconf.settings = {
      "org/virt-manager/virt-manager/connections" = {
        autoconnect = [ "qemu:///system" ];
        uris = [ "qemu:///system" ];
      };
    };
  };
}
