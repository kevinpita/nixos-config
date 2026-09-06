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
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      services.tailscale = {
        authKeyFile = "/var/lib/tailscale/bootstrap-auth-key";
        useRoutingFeatures = "both";
        extraUpFlags = lib.mkAfter [ "--advertise-exit-node" ];
      };

      systemd.services.tailscaled-autoconnect = {
        unitConfig.ConditionPathExists = config.services.tailscale.authKeyFile;
        serviceConfig = {
          Restart = "on-failure";
          RestartSec = "30s";
          TimeoutStartSec = "120s";
        };
        postStart = ''
          tailscale status --json --peers=false | jq -e '.BackendState == "Running"' > /dev/null
          ${pkgs.coreutils}/bin/rm -f -- ${lib.escapeShellArg config.services.tailscale.authKeyFile}
        '';
      };
    };
}
