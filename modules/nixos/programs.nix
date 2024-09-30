{ pkgs, ... }:
{

  environment.systemPackages = with pkgs; [
    vim
    neovim
    lazygit

    htop
    fastfetch

    bat
    fzf
    ripgrep
    tree

    curl
    wget
    mqttui

    go
  ];
}
