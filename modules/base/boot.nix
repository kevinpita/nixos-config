{
  flake.modules.nixos.base =
    { inputs, pkgs, ... }:
    {
      boot = {
        loader = {
          efi.canTouchEfiVariables = true;
          grub = {
            configurationLimit = 5;
            default = "saved";
            devices = [ "nodev" ];
            efiSupport = true;
            enable = true;
            theme = inputs.nixos-grub-themes.packages.${pkgs.stdenv.hostPlatform.system}.nixos;
          };
        };
        kernelPackages = pkgs.linuxPackages_latest;
      };

      time.hardwareClockInLocalTime = true;
    };
}
