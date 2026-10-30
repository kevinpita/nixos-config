# herdr-core (`hc`) runs the terminals on every host. The herdr app on
# workstations draws them, and reaches the servers' cores over SSH
# (herdr-ssh-client in herdr-remote-host.nix). Over SSH, `hc` alone opens a
# terminal picker.
{
  flake.modules.nixos = {
    base =
      { pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.herdr-core ];
      };

    server =
      { username, ... }:
      {
        # hc runs its core as a systemd user service. Without linger, the
        # core and its terminals stop when the last login ends.
        users.users.${username}.linger = true;
      };

    workstation =
      { pkgs, username, ... }:
      {
        environment.systemPackages = [ pkgs.herdr ];

        # Adds omp to the app's "Start an agent" menu. omp is a pi fork, so it
        # uses the shipped pi icon.
        home-manager.users.${username}.xdg.configFile."herdr-app/programs.json".text = builtins.toJSON {
          programs.omp = {
            name = "omp";
            icon = "icons/pi.svg";
            tint = true;
            tile = "#1c1d21";
            color = "#ffffff";
            run = [ "omp" ];
          };
        };
      };
  };
}
