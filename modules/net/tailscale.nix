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
        extraSetFlags = [
          "--operator=${username}"
          "--ssh"
          "--accept-routes"
        ];
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
        extraSetFlags = lib.mkAfter [ "--advertise-exit-node" ];
        # `tailscale up` rejects omitting non-default prefs, so re-authentication must repeat them.
        extraUpFlags = config.services.tailscale.extraSetFlags;
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
