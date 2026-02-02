{
  inputs,
  hostname,
  username,
  ...
}:
let
  hasSecrets = inputs ? nixos-secrets;
  secretsPath = if hasSecrets then "${inputs.nixos-secrets}/secrets" else null;
in
{
  config = {
    sops = {
      defaultSopsFile = if hasSecrets then "${secretsPath}/${hostname}.yaml" else null;

      age.keyFile = "/var/lib/sops-nix/key.txt";

      age.generateKey = true;
    };

    sops.secrets = {
      "user-password" = {
        sopsFile = "${secretsPath}/common.yaml";
        neededForUsers = true;
      };
      "ssh-auth-key" = {
        owner = username;
        path = "/home/${username}/.ssh/id_ed25519";
        mode = "0600";
      };
      "ssh-auth-key-pub" = {
        owner = username;
        path = "/home/${username}/.ssh/id_ed25519.pub";
        mode = "0644";
      };
      "ssh-sign-key" = {
        owner = username;
        path = "/home/${username}/.ssh/id_ed25519_sign";
        mode = "0600";
      };
      "ssh-sign-key-pub" = {
        owner = username;
        path = "/home/${username}/.ssh/id_ed25519_sign.pub";
        mode = "0644";
      };
    };
  };
}
