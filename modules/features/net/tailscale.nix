{
  config,
  lib,
  inputs,
  ...
}:
let
  hasSecrets = inputs ? nixos-secrets;
  secretsPath = if hasSecrets then "${inputs.nixos-secrets}/secrets" else null;
in
lib.mkIf config.features.tailscale.enable {
  sops.secrets."tailscale-key" = {
    sopsFile = "${secretsPath}/common.yaml";
  };

  services.tailscale = {
    enable = true;
    authKeyFile = config.sops.secrets."tailscale-key".path;
    openFirewall = true;
    useRoutingFeatures = if config.features.desktop.enable then "client" else "both";
    extraUpFlags = [
      "--ssh"
      "--accept-routes"
    ]
    ++ lib.optional (!config.features.desktop.enable) "--advertise-exit-node";
  };
}
