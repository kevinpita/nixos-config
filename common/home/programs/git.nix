_:

{
  programs.git = {
    enable = true;
    userName = "kevinpita";
    userEmail = "gitkevin@pm.me";
    extraConfig = {
      init.defaultBranch = "main";
      commit.gpgsign = true;
      tag.gpgsign = true;
      gpg.format = "ssh";
      user.signingkey = "~/.ssh/sign.pub";
    };
  };
}
