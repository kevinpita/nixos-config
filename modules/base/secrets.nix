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
      secretsPath = if inputs ? nixos-secrets then "${inputs.nixos-secrets}/secrets" else null;
      hasRealSecrets = secretsPath != null && builtins.pathExists "${secretsPath}/common.yaml";
      sshConfigHosts = [
        "amdep"
        "t14g6"
        "t480s"
      ];
    in
    {
      config = {
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
          }
          // lib.optionalAttrs (builtins.elem hostname sshConfigHosts) {
            "ssh-config" = {
              sopsFile = "${secretsPath}/sshconfig.yaml";
              owner = username;
              path = "/home/${username}/.ssh/config";
              mode = "0600";
            };
          };
        };
      };
    };
}
