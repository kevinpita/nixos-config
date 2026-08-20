{
  flake.modules.nixos.base =
    {
      config,
      inputs,
      hostname,
      lib,
      username,
      ...
    }:
    let
      secretsPath = if inputs ? nixos-secrets then "${inputs.nixos-secrets}/secrets" else null;
      hasRealSecrets = secretsPath != null && builtins.pathExists "${secretsPath}/common.yaml";
    in
    {
      options.hostSecrets.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Deploy this host's sops secrets.";
      };

      config = lib.mkIf config.hostSecrets.enable {
        sops = {
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
    };
}
