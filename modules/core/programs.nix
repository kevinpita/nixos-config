{
  pkgs,
  username,
  ...
}:
{
  services.fwupd.enable = true;

  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      extraArgs = "--keep-since 15d --keep 10";
    };
    flake = "/home/${username}/nixos-config";
  };

  environment.systemPackages = with pkgs; [
    neovim
    vim

    bat
    fzf
    ripgrep
    tree

    curl
    wget

    dmidecode
    fastfetch
    htop
    i2c-tools
    lm_sensors
    pciutils
    screen

    age
    sops

    # Nix helpers (for nh)
    nix-output-monitor
    nvd
  ];
}
