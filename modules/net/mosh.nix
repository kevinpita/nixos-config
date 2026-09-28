{
  flake.modules.nixos.mosh =
    { config, ... }:
    {
      programs.mosh = {
        enable = true;
        openFirewall = false;
      };

      networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedUDPPortRanges = [
        {
          from = 60000;
          to = 61000;
        }
      ];
    };
}
