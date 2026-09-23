{ inputs, ... }:
{
  flake.modules.nixos.workstation = {
    imports = [ inputs.orca-nix.nixosModules.default ];

    programs.orca-ide.enable = true;
  };

  flake.modules.nixos.server =
    {
      config,
      lib,
      username,
      ...
    }:
    {
      imports = [ inputs.orca-nix.nixosModules.default ];

      services.orca-ide = {
        enable = true;
        user = username;
        pairingAddress = "${config.networking.hostName}.tail235c8.ts.net";
      };

      assertions = [
        {
          assertion = config.services.tailscale.enable && config.networking.firewall.enable;
          message = "Orca requires Tailscale and the host firewall to limit server access.";
        }
        {
          assertion = !lib.elem config.services.orca-ide.port config.networking.firewall.allowedTCPPorts;
          message = "Do not open the Orca server port on every network interface.";
        }
      ];

      # Orca listens on all addresses. Only accept incoming connections on Tailscale.
      networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts = [
        config.services.orca-ide.port
      ];

      systemd.services.orca-ide = {
        wants = [ "tailscaled.service" ];
        after = [ "tailscaled.service" ];
      };
    };
}
