{
  flake.modules.nixos.selfhosted = {
    services.grafana.provision.dashboards.settings.providers = [
      {
        name = "selfhosted";
        folder = "Monitoring";
        folderUid = "selfhosted";
        type = "file";
        disableDeletion = false;
        allowUiUpdates = false;
        options.path = ./dashboards;
      }
    ];
  };
}
