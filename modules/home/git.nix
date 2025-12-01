_:

{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Kevin Pita";
        email = "gitkevin@pm.me";
      };
      init.defaultBranch = "main";
      commit.gpgsign = true;
      tag.gpgsign = true;
      gpg.format = "ssh";
      user.signingkey = "~/.ssh/sign.pub";
      pull.rebase = true;
    };
  };
}
