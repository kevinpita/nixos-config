{
  # A second tailscaled for the work tailnet. Userspace networking keeps it off
  # the routing table and system DNS, so the personal tailnet stays primary and
  # personal devices never join the work tailnet. Reach work hosts through the
  # local proxies or `tailscale-work nc`. Chrome sends every tailnet address
  # (100.64.0.0/10) and *.ts.net name through the work proxy.
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
      socks5 = "127.0.0.1:1055";
      pac = ''
        function FindProxyForURL(url, host) {
          if (dnsDomainIs(host, ".ts.net")) return "SOCKS5 ${socks5}";
          var ip = dnsResolve(host);
          if (ip && isInNet(ip, "100.64.0.0", "255.192.0.0")) return "SOCKS5 ${socks5}";
          return "DIRECT";
        }
      '';
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
            "--socks5-server=${socks5}"
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

      # Only Google Chrome reads /etc/opt/chrome; programs.chromium would also
      # apply the proxy to Chromium and Brave.
      environment.etc."opt/chrome/policies/managed/tailscale-work.json".text = builtins.toJSON {
        ProxySettings = {
          ProxyMode = "pac_script";
          ProxyPacUrl = "data:application/x-ns-proxy-autoconfig,${lib.escapeURL pac}";
        };
      };

      home-manager.users.${username}.programs.zsh.shellAliases = {
        tw = "tailscale-work";
        tssh = "tailscale-work ssh";
      };
    };
}
