# Core programs module - essential CLI tools and nh helper
{
  pkgs,
  username,
  ...
}:
{
  # nh (NixOS helper) configuration
  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      extraArgs = "--keep-since 15d --keep 10";
    };
    flake = "/home/${username}/nixos-config";
  };

  # Core CLI tools (always installed)
  environment.systemPackages = with pkgs; [
    # Editors
    neovim
    vim

    # File utilities
    bat
    fzf
    ripgrep
    tree

    # Network utilities
    curl
    wget

    # System monitoring
    dmidecode
    fastfetch
    htop
    i2c-tools
    lm_sensors
    pciutils
    screen

    # Nix helpers (for nh)
    nix-output-monitor
    nvd
  ];
}
