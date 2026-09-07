{ config, lib, ... }:
let
  fium = config.flake.nixosConfigurations.fium;
  withTelegram =
    (fium.extendModules {
      specialArgs.ciMode = false;
      modules = [ { selfhosted.metrics.telegram.enable = lib.mkForce true; } ];
    }).config;
  ciWithTelegram =
    (fium.extendModules {
      specialArgs.ciMode = true;
      modules = [ { selfhosted.metrics.telegram.enable = lib.mkForce true; } ];
    }).config;
  withoutTelegram =
    (fium.extendModules {
      modules = [ { selfhosted.metrics.telegram.enable = lib.mkForce false; } ];
    }).config;
in
{
  perSystem =
    { pkgs, ... }:
    {
      checks.monitoring-alerts =
        assert
          ciWithTelegram.services.prometheus.alertmanager.configText
          == withoutTelegram.services.prometheus.alertmanager.configText;
        assert !(builtins.hasAttr "telegram-bot-token" ciWithTelegram.sops.secrets);
        pkgs.runCommand "monitoring-alerts"
          {
            nativeBuildInputs = with pkgs; [
              python3
              prometheus.cli
              prometheus-alertmanager
              envsubst
            ];
          }
          ''
            cp ${builtins.head fium.config.services.prometheus.ruleFiles} rules.json
            cp ${pkgs.writeText "alertmanager-disabled.json" withoutTelegram.services.prometheus.alertmanager.configText} disabled.json
            cp ${pkgs.writeText "alertmanager-telegram.template" withTelegram.services.prometheus.alertmanager.configText} telegram.template
            python ${../../tests/monitoring-alerts.py}
            touch $out
          '';
    };
}
