{ config, ... }:
let
  inherit (config.flake.modules.nixos) server kubernetes-client;
in
{
  flake.modules.nixos.kubernetes-server =
    { config, ... }:
    {
      imports = [
        server
        kubernetes-client
      ];

      services.k3s = {
        enable = true;
        role = "server";
        disable = [
          "servicelb"
          "traefik"
        ];
        extraFlags = [
          "--tls-san=${config.networking.hostName}"
          "--write-kubeconfig-mode=0600"
        ];
        extraKubeletConfig = {
          failSwapOn = false;
          memorySwap.swapBehavior = "NoSwap";
        };
      };

      networking.firewall = {
        interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts = [ 6443 ];
        trustedInterfaces = [
          "cni0"
          "flannel.1"
        ];
      };
    };
}
