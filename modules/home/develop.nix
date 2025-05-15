_: {
  programs = {
    tmux = {
      enable = true;
      terminal = "tmux-256color";
    };

    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };
  };
}
