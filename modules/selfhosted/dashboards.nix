{
  flake.modules.nixos.selfhosted = {
    services.grafana.provision.dashboards.settings.providers = [
      {
        name = "selfhosted";
        type = "file";
        disableDeletion = false;
        allowUiUpdates = false;
        options.path = ./dashboards;
      }
    ];
  };
}
