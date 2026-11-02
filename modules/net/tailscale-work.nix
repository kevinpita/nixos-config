{
  # A second tailscaled for the work tailnet. Userspace networking keeps it off
  # the routing table and system DNS, so the personal tailnet stays primary and
  # personal devices never join the work tailnet. Reach work hosts through the
  # local proxies or `tailscale-work nc`.
  flake.modules.nixos.workstation =
    {
      config,
      lib,
      pkgs,
      username,
      ...
    }:
    let
      tailscale = config.services.tailscale.package;
      socket = "/run/tailscale-work/tailscaled.sock";
    in
    {
      systemd.services.tailscaled-work = {
        description = "Tailscale for the work tailnet (userspace, proxy only)";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          ExecStart = lib.escapeShellArgs [
            "${tailscale}/bin/tailscaled"
            "--tun=userspace-networking"
            "--statedir=/var/lib/tailscale-work"
            "--socket=${socket}"
            # The personal tailscaled uses the default port 41641.
            "--port=41642"
            "--socks5-server=127.0.0.1:1055"
            "--outbound-http-proxy-listen=127.0.0.1:1056"
          ];
          DynamicUser = true;
          StateDirectory = "tailscale-work";
          RuntimeDirectory = "tailscale-work";
          Restart = "on-failure";
        };
      };

      environment.systemPackages = [
        (pkgs.writeShellScriptBin "tailscale-work" ''
          exec ${tailscale}/bin/tailscale --socket=${socket} "$@"
        '')
      ];

      home-manager.users.${username}.programs.zsh.shellAliases = {
        tw = "tailscale-work";
        tssh = "tailscale-work ssh";
      };
    };
}
