{ pkgs, ... }:
{

  environment.systemPackages = with pkgs; [
    gemini-cli
    neovim
    vim

    dmidecode
    fastfetch
    htop
    i2c-tools
    lm_sensors
    pciutils
    screen

    bat
    fzf
    ripgrep
    tree

    curl
    mqttui
    wget

    go

    lazydocker
    lazysql
  ];
}
