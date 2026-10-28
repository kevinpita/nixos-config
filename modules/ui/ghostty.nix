{ inputs, ... }:
{
  flake.modules.nixos.base = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.ghostty.terminfo ];
  };

  flake.modules.nixos.ghostty =
    {
      lib,
      pkgs,
      username,
      ...
    }:
    {
      assertions = [
        {
          assertion = lib.versionOlder pkgs.ghostty.version "1.4.0";
          message = "nixpkgs now has Ghostty ${pkgs.ghostty.version}. Remove the ghostty flake input and its Cachix settings, and use pkgs.ghostty again in modules/ui/ghostty.nix.";
        }
      ];

      nix.settings = {
        extra-substituters = [ "https://ghostty.cachix.org" ];
        extra-trusted-public-keys = [
          "ghostty.cachix.org-1:QB389yTa6gTyneehvqG58y0WnHjQOqgnA+wBnpWWxns="
        ];
      };

      home-manager.users.${username} = {
        programs.ghostty = {
          enable = true;
          package = inputs.ghostty.packages.${pkgs.stdenv.hostPlatform.system}.default;
          settings = {
            font-family = "JetBrains Mono Nerd Font";
            font-size = 20;
            background = "#1d1f21";
            background-opacity = 0.95;
            term = "xterm-ghostty";
            shell-integration = "zsh";
            shell-integration-features = "cursor,sudo,title,ssh-env,ssh-terminfo";
          };
        };
      };
    };
}
