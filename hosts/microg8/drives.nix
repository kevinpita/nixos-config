{
  services.smartd.enable = true;

  services.btrfs.autoScrub = {
    enable = true;
    fileSystems = [
      "/"
      "/data"
    ];
    interval = "weekly";
  };
}
