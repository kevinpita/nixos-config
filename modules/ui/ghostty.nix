{
  flake.modules.nixos.base = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.ghostty.terminfo ];
  };

  flake.modules.nixos.ghostty =
    {
      username,
      ...
    }:
    {
      home-manager.users.${username} = {
        programs.ghostty = {
          enable = true;
          settings = {
            font-family = "JetBrains Mono Nerd Font";
            font-size = 20;
            background = "#1d1f21";
            background-opacity = 0.95;
            term = "xterm-ghostty";
            shell-integration = "zsh";
            shell-integration-features = "cursor,sudo,title";
          };
        };

        programs.zsh.initContent = ''
          copyterm() { infocmp -x xterm-ghostty | ssh "$1" -- tic -x -; }
        '';
      };
    };
}
