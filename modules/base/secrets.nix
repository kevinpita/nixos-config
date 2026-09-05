{
  flake.modules.nixos.base =
    {
      inputs,
      hostname,
      lib,
      username,
      ciMode,
      ...
    }:
    let
      secretsPath = "${inputs.nixos-secrets}/secrets";
      hostFile = "${secretsPath}/${hostname}.yaml";
    in
    {
      sops = {
        age.keyFile = "/var/lib/sops-nix/key.txt";
        age.generateKey = true;
      }
      // lib.optionalAttrs (!ciMode) {
        defaultSopsFile =
          if builtins.pathExists hostFile then
            hostFile
          else
            throw "nixos-secrets is missing secrets/${hostname}.yaml.";

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
