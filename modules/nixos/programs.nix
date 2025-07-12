{ pkgs, ... }:
{

  environment.systemPackages = with pkgs; [
    gemini-cli
    lazygit
    neovim
    screen
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
