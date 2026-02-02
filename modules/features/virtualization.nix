{
  config,
  lib,
  pkgs,
  username,
  ...
}:
lib.mkIf config.features.virtualization.enable {
  virtualisation.docker = {
    autoPrune.enable = true;
    enable = true;
    storageDriver = "btrfs";

    rootless = {
      enable = true;
      setSocketVariable = true;
    };
  };

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

  users.users.${username}.extraGroups = [
    "docker"
    "libvirtd"
    "kvm"
  ];

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
