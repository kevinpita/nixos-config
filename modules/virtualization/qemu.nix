{
  flake.modules.nixos.qemu =
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
        # Guest images and inspection
        libguestfs

        # Networking
        bridge-utils
        dnsmasq
        netcat-openbsd
        vde2

        # Virtual machines, firmware, and TPM
        OVMF
        qemu
        swtpm
      ];
    };

  flake.modules.nixos.workstation =
    {
      config,
      lib,
      pkgs,
      username,
      ...
    }:
    # GUI additions belong to workstation hosts that also import the QEMU aspect.
    # Libvirtd is enabled exactly by that aspect, so it remains the feature gate.
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
