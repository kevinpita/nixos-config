{ pkgs, ... }:
{

  environment.systemPackages = with pkgs; [
    vim
    neovim
    lazygit

    htop
    fastfetch

    bat
    ripgrep
    tree

    curl
    wget
    mqttui

    go
  ];
}
