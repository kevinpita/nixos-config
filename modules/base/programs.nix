{ config, ... }:
{
  flake.modules.nixos.base =
    { pkgs, ... }:
    {
      imports = with config.flake.modules.nixos; [
        ai
        git
      ];

      services.fwupd.enable = true;

      programs.ssh.startAgent = true;

      wrappers.neovim.enable = true;
      environment.variables.EDITOR = "nvim";

      environment.systemPackages = with pkgs; [
        # Archives and compression
        lz4
        unzip
        zip

        # Files and search
        bast
        bat
        fzf
        lazyrsync
        ripgrep
        tree

        # Hardware and system monitoring
        btop
        dmidecode
        fastfetch
        gdu
        i2c-tools
        lm_sensors
        lsof
        pciutils
        smartmontools

        # Scripting and structured data
        jq
        just
        yq-go

        # Terminals
        screen
      ];
    };
}
