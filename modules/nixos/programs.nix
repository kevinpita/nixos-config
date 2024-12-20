{ pkgs, ... }:
{

  environment.systemPackages = with pkgs; [
    vim
    neovim
    lazygit

    htop
    fastfetch
    lm_sensors

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
