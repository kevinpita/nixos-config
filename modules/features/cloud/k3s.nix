{
  config,
  lib,
  ...
}:
lib.mkIf config.features.k3s.enable {
  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = toString [
      "--write-kubeconfig-mode 600"
      "--node-name ${config.networking.hostName}"
      "--tls-san ${config.networking.hostName}"
    ];
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 6443 ];
}
