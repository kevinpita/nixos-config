{
  flake.modules.nixos.base =
    {
      config,
      lib,
      inputs,
      pkgs,
      ...
    }:

    with lib;

    {
      options = {
        bootloader = {
          mode = mkOption {
            type = types.enum [
              "uefi"
              "bios"
            ];
            default = "uefi";
            description = "Bootloader mode: uefi or bios";
          };
        };
        kernelPackages = mkOption {
          type = types.raw;
          default = pkgs.linuxPackages_latest;
          description = "Kernel packages to use.";
        };
        uefiOSProber = mkOption {
          type = types.bool;
          default = false;
          description = "Enable OS prober for UEFI bootloader.";
        };
      };

      config = {
        boot = mkMerge [
          (mkIf (config.bootloader.mode == "bios") {
            loader = {
              timeout = 1;
              grub = {
                enable = true;
                timeoutStyle = "hidden";
              };
            };
          })
          (mkIf (config.bootloader.mode == "uefi") {
            loader = {
              efi.canTouchEfiVariables = true;
              grub = {
                configurationLimit = 5;
                default = "saved";
                devices = [ "nodev" ];
                efiSupport = true;
                enable = true;
                theme = inputs.nixos-grub-themes.packages.${pkgs.stdenv.hostPlatform.system}.nixos;
                useOSProber = config.uefiOSProber;
              };
            };
          })
          {
            inherit (config) kernelPackages;
          }
        ];

        time.hardwareClockInLocalTime = true;
      };
    };
}
