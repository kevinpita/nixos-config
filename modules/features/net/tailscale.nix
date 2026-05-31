{
  config,
  lib,
  inputs,
  ...
}:
let
  secretsPath = if inputs ? nixos-secrets then "${inputs.nixos-secrets}/secrets" else null;
  hasRealSecrets = secretsPath != null && builtins.pathExists "${secretsPath}/common.yaml";
in
lib.mkIf config.features.tailscale.enable {
  sops.secrets = lib.mkIf hasRealSecrets {
    "tailscale-key" = {
      sopsFile = "${secretsPath}/common.yaml";
    };
  };

  services.tailscale = {
    enable = true;
    openFirewall = true;
    useRoutingFeatures = if config.features.desktop.enable then "client" else "both";
    extraUpFlags = [
      "--ssh"
      "--accept-routes"
    ]
    ++ lib.optional (!config.features.desktop.enable) "--advertise-exit-node";
  }
  // lib.optionalAttrs hasRealSecrets {
    authKeyFile = config.sops.secrets."tailscale-key".path;
  };
}
