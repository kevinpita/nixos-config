{
  flake.modules.nixos.base =
    {
      config,
      inputs,
      pkgs,
      ...
    }:
    {
      boot = {
        loader = {
          # Keep the menu up long enough to pick another OS on dual-boot hosts.
          # Single-boot hosts only need it for rollbacks.
          timeout = if config.boot.loader.grub.useOSProber then 5 else 1;
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
      };

    };

  # Graphical splash that also asks for the LUKS passphrase. It continues the
  # GRUB theme layout so leaving the boot menu looks like one screen.
  flake.modules.nixos.workstation =
    {
      config,
      inputs,
      pkgs,
      ...
    }:
    {
      boot = {
        plymouth = {
          enable = true;
          theme = "nixos-grub";
          themePackages = [
            (pkgs.callPackage ../../packages/plymouth-nixos-grub/package.nix {
              grubTheme = inputs.nixos-grub-themes.packages.${pkgs.stdenv.hostPlatform.system}.nixos;
            })
          ];
          font = "${pkgs.ubuntu-classic}/share/fonts/truetype/ubuntu/Ubuntu-R.ttf";
        };

        # Keep kernel and systemd status messages from drawing over the splash.
        consoleLogLevel = 3;
        initrd.verbose = false;
        kernelParams = [
          "quiet"
          "udev.log_level=3"
          "rd.udev.log_level=3"
          "systemd.show_status=auto"
          "rd.systemd.show_status=auto"
          # Draw on the framebuffer GRUB leaves behind instead of waiting for
          # the GPU driver. Plymouth moves to the GPU once it has loaded.
          "plymouth.use-simpledrm"
        ];
      };

      # Leave the last splash frame on screen until the compositor draws.
      systemd.services.plymouth-quit.serviceConfig.ExecStart = [
        ""
        "-${config.boot.plymouth.package}/bin/plymouth quit --retain-splash"
      ];
    };
}
