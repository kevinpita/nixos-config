{
  flake.modules.nixos.vm =
    { pkgs, username, ... }:
    {
      virtualisation.libvirtd = {
        enable = true;
        qemu = {
          package = pkgs.qemu_kvm;
          runAsRoot = true;
          swtpm.enable = true;
          # virtiofs shared folders: libvirt needs the virtiofsd binary.
          vhostUserPackages = [ pkgs.virtiofsd ];
        };
        onBoot = "ignore";
        onShutdown = "shutdown";
      };

      # With the nftables firewall backend (enabled alongside incus), libvirt's
      # NAT bridge is untrusted by default, so guest DHCP/DNS and outbound
      # traffic on virbr0 get dropped. Trust the bridge like we do for incusbr0.
      networking.firewall.trustedInterfaces = [ "virbr0" ];

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
    };

  flake.modules.nixos.desktop =
    {
      config,
      lib,
      pkgs,
      username,
      ...
    }:
    # GUI additions belong to hosts that also import the vm aspect; libvirtd
    # is enabled exactly by that aspect, so it carries the old desktop+vm gate.
    lib.mkIf config.virtualisation.libvirtd.enable {
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
    };
}
