{ inputs, pkgs, ... }:
{
  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      grub = {
        configurationLimit = 5;
        devices = [ "nodev" ];
        efiSupport = true;
        enable = true;
        theme = inputs.nixos-grub-themes.packages.${pkgs.system}.nixos;
        useOSProber = true;
      };
    };

    kernelPackages = pkgs.linuxPackages_latest;
  };
  time.hardwareClockInLocalTime = true;
}
