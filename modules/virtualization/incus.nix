{
  flake.modules.nixos.incus =
    { username, ... }:
    {
      virtualisation.incus.enable = true;

      # Incus drives its managed bridge (incusbr0) via nftables; pair the host
      # firewall with the nftables backend and trust the bridge so containers get
      # DHCP/DNS and outbound (apt/dnf) connectivity.
      networking.nftables.enable = true;
      networking.firewall.trustedInterfaces = [ "incusbr0" ];

      users.users.${username}.extraGroups = [ "incus-admin" ];
    };

  # Start incus on first use instead of during boot. Workstations run no
  # autostart instances. Servers keep starting it at boot for theirs.
  flake.modules.nixos.workstation = {
    virtualisation.incus.socketActivation = true;
  };
}
