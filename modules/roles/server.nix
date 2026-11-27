{ config, ... }:
{
  flake.modules.nixos.server =
    { pkgs, ... }:
    {
      imports = with config.flake.modules.nixos; [
        base
        herdr-remote-host
        mosh
        node-exporter
        podman
        tailscale
      ];

      environment.systemPackages = [ pkgs.forklab ];

      host.roles = [ "server" ];

      # Let the hardware watchdog reset a host whose kernel or PID 1 hangs.
      systemd.settings.Manager.RuntimeWatchdogSec = "30s";

      # Continue the boot when a stage-2 mount fails, in place of a rescue
      # shell on the local console.
      systemd.enableEmergencyMode = false;

      # A remote host that sleeps stays unreachable until someone wakes it.
      systemd.sleep.settings.Sleep = {
        AllowSuspend = "no";
        AllowHibernation = "no";
      };

      # Builds yield to the hosted services and to interactive work.
      nix = {
        daemonCPUSchedPolicy = "batch";
        daemonIOSchedClass = "idle";
      };

      # When memory runs out, prefer a build as the victim over a service.
      systemd.services.nix-daemon.serviceConfig.OOMScoreAdjust = 250;
    };
}
