{
  flake.modules.nixos = {
    server =
      { pkgs, ... }:
      {
        environment.systemPackages = [ pkgs.amp-cli ];
      };

    amp-runner =
      {
        hostname,
        lib,
        pkgs,
        username,
        ...
      }:
      {
        users.users.${username}.linger = true;

        home-manager.users.${username}.systemd.user.services.amp-runner = {
          Unit = {
            Description = "Amp remote thread runner";
            StartLimitIntervalSec = 0;
          };
          Service = {
            ExecStart = "${lib.getExe pkgs.amp-cli} --no-tui --runner-id ${hostname}";
            WorkingDirectory = "%h";
            Environment = "PATH=%h/.local/bin:%h/.nix-profile/bin:/etc/profiles/per-user/${username}/bin:/run/current-system/sw/bin:/run/wrappers/bin";
            Restart = "always";
            RestartSec = 5;
          };
          Install.WantedBy = [ "default.target" ];
        };
      };
  };
}
