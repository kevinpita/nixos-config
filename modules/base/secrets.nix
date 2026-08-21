{
  flake.modules.nixos.base =
    {
      inputs,
      hostname,
      lib,
      username,
      ...
    }:
    let
      secretsPath = "${inputs.nixos-secrets}/secrets";
      hasRealSecrets = builtins.pathExists "${secretsPath}/common.yaml";
    in
    {
      options.hostSecrets.available = lib.mkOption {
        type = lib.types.bool;
        readOnly = true;
        default = hasRealSecrets;
        description = "Real sops secrets are present (false under the CI dummy input).";
      };

      config.sops = {
        age.keyFile = "/var/lib/sops-nix/key.txt";

        age.generateKey = true;
      }
      // lib.optionalAttrs hasRealSecrets {
        defaultSopsFile = "${secretsPath}/${hostname}.yaml";

        secrets = {
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
    };
}
