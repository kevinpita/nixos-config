{ inputs, ... }:
{
  flake.modules.nixos.server =
    {
      config,
      pkgs,
      username,
      ...
    }:
    {
      imports = [ inputs.comin.nixosModules.comin ];

      services.comin = {
        enable = true;
        exporter.openFirewall = false;
        remotes = [
          {
            name = "origin";
            url = "https://github.com/kevinpita/nixos-config.git";
            branches.main.name = "main";
          }
        ];
      };

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
