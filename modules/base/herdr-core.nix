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
      { pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.herdr ];
      };
  };
}
