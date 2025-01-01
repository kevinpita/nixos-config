{ pkgs, ... }:
{

  environment.systemPackages = with pkgs; [
    screen
    lazygit
    neovim
    vim

    dmidecode
    fastfetch
    htop
    i2c-tools
    lm_sensors
    pciutils

    bat
    fzf
    ripgrep
    tree

    curl
    mqttui
    wget

    go
    python3Full
  ];
}
