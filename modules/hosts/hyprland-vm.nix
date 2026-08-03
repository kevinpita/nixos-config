{
  config,
  lib,
  ...
}:
{
  flake.modules.nixos."hosts/hyprland-vm" =
    {
      lib,
      username,
      ...
    }:
    {
      imports = [ config.flake.modules.nixos."hyprland-desktop" ];

      hostSecrets.enable = false;

      # Keep the disposable desktop guest isolated from host services and data.
      services = {
        fwupd.enable = lib.mkForce false;
        syncthing.enable = lib.mkForce false;
        tailscale.enable = lib.mkForce false;
      };

      security.sudo.wheelNeedsPassword = false;
      users.users.${username}.initialPassword = "nixos";

      # Keep the regular host evaluation valid. The VM variant overrides this
      # with its persistent qcow2 root filesystem.
      fileSystems."/" = {
        device = "none";
        fsType = "tmpfs";
      };

      virtualisation.vmVariant = {
        virtualisation = {
          cores = 4;
          memorySize = 8192;
          diskSize = 40960;
          qemu = {
            forceAccel = true;
            options = [
              "-vga none"
              "-device virtio-vga-gl"
              "-display gtk,gl=on"
            ];
          };
        };
      };
    };

  perSystem =
    { pkgs, ... }:
    let
      vm = config.flake.nixosConfigurations.hyprland-vm.config.system.build.vm;
      launcher = pkgs.writeShellApplication {
        name = "hyprland-vm";
        text = ''
          state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/hyprland-vm"
          ${pkgs.coreutils}/bin/mkdir -p "$state_dir"
          cd "$state_dir"
          exec ${lib.getExe vm} "$@"
        '';
      };
    in
    {
      apps.hyprland-vm = {
        type = "app";
        program = lib.getExe launcher;
        meta.description = "Build and run the persistent Hyprland test VM";
      };
    };
}
