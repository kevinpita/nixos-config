{
  config,
  lib,
  ...
}:
{
  flake.modules.nixos."hosts/hyprland-vm" =
    {
      lib,
      pkgs,
      username,
      ...
    }:
    let
      displayAutoresize = pkgs.writeShellApplication {
        name = "hyprland-vm-display-autoresize";
        runtimeInputs = with pkgs; [
          hyprland
          systemd
        ];
        text = ''
          pending_pid=""

          cleanup() {
            if [[ -n "$pending_pid" ]]; then
              kill "$pending_pid" 2>/dev/null || true
            fi
          }
          trap cleanup EXIT

          apply_preferred_mode() {
            sleep 0.2
            hyprctl keyword monitor ",preferred,auto,1" >/dev/null
          }

          while read -r source _ action _; do
            if [[ "$source" != "UDEV" || "$action" != "change" ]]; then
              continue
            fi

            if [[ -n "$pending_pid" ]]; then
              kill "$pending_pid" 2>/dev/null || true
            fi
            apply_preferred_mode &
            pending_pid=$!
          done < <(udevadm monitor --udev --subsystem-match=drm)
        '';
      };
    in
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

      home-manager.users.${username}.systemd.user.services.hyprland-vm-display-autoresize = {
        Unit = {
          Description = "Resize the Hyprland display with the QEMU window";
          After = [ "hyprland-session.target" ];
          PartOf = [ "hyprland-session.target" ];
        };

        Service = {
          ExecStart = lib.getExe displayAutoresize;
          Restart = "always";
          RestartSec = 1;
        };

        Install.WantedBy = [ "hyprland-session.target" ];
      };

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
              "-device virtio-vga-gl,edid=on"
              "-display gtk,gl=on,zoom-to-fit=on,grab-on-hover=on"
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
