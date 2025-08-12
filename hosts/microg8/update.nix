_: {
  services.comin = {
    enable = true;
    remotes = [
      {
        name = "origin";
        url = "https://github.com/kevinpita/nixos-config.git";
        branches.main.name = "main";
      }
    ];
  };
}
