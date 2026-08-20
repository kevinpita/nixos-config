{
  flake.modules.nixos.tailscale =
    {
      username,
      ...
    }:
    {
      services.tailscale = {
        enable = true;
        openFirewall = true;
        extraUpFlags = [
          "--ssh"
          "--accept-routes"
        ];
        extraSetFlags = [ "--operator=${username}" ];
      };
    };

  flake.modules.nixos.workstation = {
    services.tailscale.useRoutingFeatures = "client";
  };

  flake.modules.nixos.server =
    { lib, ... }:
    {
      services.tailscale = {
        useRoutingFeatures = "both";
        extraUpFlags = lib.mkAfter [ "--advertise-exit-node" ];
      };
    };
}
