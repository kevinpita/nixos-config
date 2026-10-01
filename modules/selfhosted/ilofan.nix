{ inputs, ... }:
{
  flake.modules.nixos.ilofan =
    {
      config,
      lib,
      pkgs,
      ciMode,
      username,
      ...
    }:
    let
      metricsPort = 9877;
    in
    {
      imports = [ inputs.ilofan.nixosModules.default ];

      sops.secrets = lib.mkIf (!ciMode) {
        ilofan-password.restartUnits = [ "ilofan.service" ];
      };

      services.ilofan = {
        enable = true;
        package = inputs.ilofan.packages.${pkgs.stdenv.hostPlatform.system}.default;
        passwordFile =
          if ciMode then "/run/secrets/ilofan-password" else config.sops.secrets.ilofan-password.path;
        settings.metricsAddress = ":${toString metricsPort}";
      };

      users.users.${username}.extraGroups = [ "ilofan" ];

      networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts = [
        metricsPort
      ];
    };
}
