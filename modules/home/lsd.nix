_: {
  programs.lsd = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      date = "relative";
      ignore-globs = [
        ".git"
      ];
      total-size = true;
      sorting.dir-grouping = "first";
    };
  };
}
