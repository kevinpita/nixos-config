{ inputs, ... }:
{
  flake.modules.nixos.server =
    {
      config,
      lib,
      pkgs,
      username,
      ...
    }:
    {
      imports = [ inputs.comin.nixosModules.comin ];

      services.comin = {
        enable = true;
        exporter.openFirewall = false;
        postDeploymentCommand = lib.getExe (
          pkgs.writeShellApplication {
            name = "comin-deployment-metric";
            runtimeInputs = [ pkgs.coreutils ];
            text = ''
              exec ${pkgs.bash}/bin/bash ${./comin-deployment-metric.sh} /var/lib/comin-metrics
            '';
          }
        );
        remotes = [
          {
            name = "origin";
            url = "https://github.com/kevinpita/nixos-config.git";
            branches.main.name = "main";
          }
        ];
        # Deploy only commits signed by a key registered on the GitHub account.
        sshAllowedSignersPath = toString (
          pkgs.writeText "comin-allowed-signers" ''
            gitkevin@pm.me ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBX+ddd0ggth5BzrXK0txLvhv5CJ/YmEoIKTxMMu0UPl
            gitkevin@pm.me ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICmyCKJkx6origo1A7JAEy8KSEqnDf2F8bMICLf2khIK
            gitkevin@pm.me ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDfbHR9tJn6nhBhWadyR5U8wNIOxmgz8ZyN07FUvXpvF
            gitkevin@pm.me ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICu5mC/cYIUBzI38YXIb8GNTQo1maEHGJEEbdthkVngT
            gitkevin@pm.me ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPnec7ynN2CfIXOy8cfeRt6j2ICZtxPwel6btoQ9nZo4
          ''
        );
      };

      # Persist the timestamp across Comin restarts and export it through node-exporter.
      systemd.tmpfiles.rules = [ "d /var/lib/comin-metrics 0755 root root -" ];
      services.prometheus.exporters.node.extraFlags = [
        "--collector.textfile.directory=/var/lib/comin-metrics"
      ];

      assertions = [
        {
          assertion = config.services.tailscale.enable && config.networking.firewall.enable;
          message = "Comin metrics requires Tailscale and the host firewall.";
        }
      ];

      networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts = [
        config.services.comin.exporter.port
      ];

      # Pin GitHub's host key for unattended private flake input fetches.
      programs.ssh.knownHosts."github.com".publicKey =
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";

      systemd.services.comin = {
        after = [ "sops-nix.service" ];
        # SOPS installs this key before Comin fetches the private inputs.
        # Keep activation as root, but reuse the user's GitHub identity.
        environment.GIT_SSH_COMMAND =
          "${pkgs.openssh}/bin/ssh -F /dev/null"
          + " -i /home/${username}/.ssh/id_ed25519"
          + " -o IdentitiesOnly=yes -o BatchMode=yes"
          + " -o StrictHostKeyChecking=yes"
          + " -o UserKnownHostsFile=/dev/null"
          + " -o GlobalKnownHostsFile=/etc/ssh/ssh_known_hosts";
      };
    };
}
