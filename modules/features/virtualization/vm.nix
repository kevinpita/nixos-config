{
  config,
  lib,
  pkgs,
  username,
  ...
}:
lib.mkIf config.features.virtualization.vm.enable (
  lib.mkMerge [
    {
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

      users.users.${username}.extraGroups = [
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
        swtpm
      ];
    }

    (lib.mkIf config.features.desktop.enable {
      virtualisation.spiceUSBRedirection.enable = true;

      programs.dconf.enable = true;
      programs.virt-manager.enable = true;

      environment.systemPackages = with pkgs; [
        spice-gtk
        virtio-win
      ];

      home-manager.users.${username} = {
        home.packages = with pkgs; [
          virt-viewer
        ];

        dconf.settings = {
          "org/virt-manager/virt-manager/connections" = {
            autoconnect = [ "qemu:///system" ];
            uris = [ "qemu:///system" ];
          };
        };
      };
    })
  ]
)
