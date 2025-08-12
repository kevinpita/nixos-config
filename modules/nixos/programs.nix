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

    curl
    mqttui
    wget

    go
    python3Full

    lazydocker
    lazysql
  ];
}
