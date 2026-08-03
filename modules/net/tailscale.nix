{
  flake.modules.nixos.tailscale =
    {
      config,
      lib,
      inputs,
      username,
      ...
    }:
    let
      secretsPath = if inputs ? nixos-secrets then "${inputs.nixos-secrets}/secrets" else null;
      hasRealSecrets =
        config.hostSecrets.enable
        && secretsPath != null
        && builtins.pathExists "${secretsPath}/common.yaml";
    in
    {
      sops.secrets = lib.mkIf hasRealSecrets {
        "tailscale-key" = {
          sopsFile = "${secretsPath}/common.yaml";
        };
      };

      services.tailscale = {
        enable = true;
        openFirewall = true;
        extraUpFlags = [
          "--ssh"
          "--accept-routes"
        ];
        extraSetFlags = [ "--operator=${username}" ];
      }
      // lib.optionalAttrs hasRealSecrets {
        authKeyFile = config.sops.secrets."tailscale-key".path;
      };
    };

  flake.modules.nixos.workstation = {
    services.tailscale.useRoutingFeatures = "client";
  };

  flake.modules.nixos.server =
    { lib, ... }:
    {
      services.tailscale = {
        useRoutingFeatures = "both";
        extraUpFlags = lib.mkAfter [ "--advertise-exit-node" ];
      };
    };
}
