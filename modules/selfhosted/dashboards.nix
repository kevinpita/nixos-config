{
  flake.modules.nixos.selfhosted = {
    services.grafana.provision.dashboards.settings.providers = [
      {
        name = "selfhosted";
        folder = "Selfhosted";
        type = "file";
        disableDeletion = false;
        allowUiUpdates = false;
        options.path = ./dashboards;
      }
    ];
  };
}
