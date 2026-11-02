{
  flake.modules.nixos.development =
    { pkgs, ... }:
    let
      # OS sandbox for running untrusted target code, used by the security-audit skill.
      sandboxRun = pkgs.writeShellApplication {
        name = "sandbox-run";
        runtimeInputs = with pkgs; [
          bubblewrap
          coreutils
          systemd
        ];
        # systemd-run --user needs the user bus, which agent shells sometimes lack.
        text = ''
          export XDG_RUNTIME_DIR=''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
          export DBUS_SESSION_BUS_ADDRESS=''${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}
        ''
        + builtins.readFile ./sandbox-run.sh;
      };
    in
    {
      environment.systemPackages = [ sandboxRun ];
    };
}
