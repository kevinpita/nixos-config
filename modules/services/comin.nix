{ inputs, ... }:
{
  flake.modules.nixos.server =
    { pkgs, username, ... }:
    {
      imports = [ inputs.comin.nixosModules.comin ];

      services.comin = {
        enable = true;
        remotes = [
          {
            name = "origin";
            url = "https://github.com/kevinpita/nixos-config.git";
            branches.main.name = "main";
          }
        ];
      };

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
