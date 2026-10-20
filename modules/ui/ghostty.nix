{
  flake.modules.nixos.base = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.ghostty.terminfo ];
  };

  flake.modules.nixos.ghostty =
    {
      pkgs,
      username,
      ...
    }:
    {
      home-manager.users.${username} = {
        programs.ghostty = {
          enable = true;
          # Kitty protocol apps such as herdr get `[` and `{` twice on the es
          # layout, because Ghostty 1.3.1 also sends text on key release.
          # Remove after the next Ghostty release, which includes this fix.
          package = pkgs.ghostty.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [
              (pkgs.fetchpatch {
                url = "https://github.com/ghostty-org/ghostty/commit/602497e9b96c62b05c4c6418538192ad974e4326.patch";
                hash = "sha256-m+OgKw+twO8DAX+hKOYp0nxbSXKkpO6ze7N1ImkJShU=";
              })
            ];
          });
          settings = {
            font-family = "JetBrains Mono Nerd Font";
            font-size = 20;
            background = "#1d1f21";
            background-opacity = 0.95;
            term = "xterm-ghostty";
            shell-integration = "zsh";
            shell-integration-features = "cursor,sudo,title,ssh-terminfo";
          };
        };

        programs.zsh.initContent = ''
          copyterm() { infocmp -x xterm-ghostty | ssh "$1" -- tic -x -; }
        '';
      };
    };
}
