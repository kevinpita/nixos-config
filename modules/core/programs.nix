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

  wrappers.neovim.enable = true;
  environment.variables.EDITOR = "nvim";

  environment.systemPackages = with pkgs; [
    bat
    fzf
    ripgrep
    tree

    curl
    jq
    wget
    zip

    dmidecode
    fastfetch
    bottom
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
