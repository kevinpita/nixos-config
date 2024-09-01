{ username, ... }:

{
  imports = [
    (import ../../common/home { inherit username; })

    ../../common/home/packages/gui.nix
    ../../common/home/packages/multimedia.nix
    ../../common/home/packages/dev.nix
  ];

  programs = {
    fastfetch.enable = true;
    neovim.enable = true;
    ripgrep.enable = true;
    lazygit.enable = true;

    htop.enable = true;
    bat.enable = true;
    chromium.enable = true;
  };
}
