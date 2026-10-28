{
  flake.modules.nixos.server =
    {
      config,
      lib,
      pkgs,
      username,
      ...
    }:
    let
      port = 7317;
      tailscale = lib.getExe config.services.tailscale.package;
    in
    {
      # Herdr starts Ovis with its server. Ovis listens on loopback only.
      # Tailscale Serve is its only ingress, so this disables its Portal tunnel.
      # The nodes are tagged and have no owner login, so the owner is named here.
      # Other logins are refused. Tagged nodes must pair.
      home-manager.users.${username}.programs.herdr.plugins.ovis = {
        source = pkgs.ovis;
        configFiles.env.text = ''
          HOST=127.0.0.1
          PORT=${toString port}
          OVIS_TAILSCALE_SERVE_ONLY=1
          OVIS_TAILSCALE_HTTPS_PORT=${toString port}
          OVIS_TAILSCALE_OWNER=kevinpigar@gmail.com
          OVIS_TELEMETRY=0
        '';
      };

      # Serve matches the Host header, so clients must use the MagicDNS name.
      # The phone app needs HTTPS to install and to receive push alerts.
      systemd.services.ovis-serve = {
        description = "Publish Ovis on the tailnet";
        wantedBy = [ "multi-user.target" ];
        after = [
          "tailscaled.service"
          "tailscaled-autoconnect.service"
          "tailscaled-set.service"
        ];
        wants = [ "tailscaled.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${tailscale} serve --bg --https=${toString port} http://127.0.0.1:${toString port}";
          ExecStop = "${tailscale} serve --https=${toString port} off";
          # tailscaled can start before the node is logged in.
          Restart = "on-failure";
          RestartSec = "30s";
        };
      };
    };
}
