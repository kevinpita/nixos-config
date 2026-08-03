{
  flake.modules.nixos.sops-admin =
    {
      config,
      lib,
      inputs,
      username,
      ...
    }:
    let
      secretsPath = if inputs ? nixos-secrets then "${inputs.nixos-secrets}/secrets" else null;
      hasRealSecrets =
        config.hostSecrets.enable
        && secretsPath != null
        && builtins.pathExists "${secretsPath}/personal.yaml";
    in
    lib.mkIf hasRealSecrets {
      sops.secrets."age-secret" = {
        sopsFile = "${secretsPath}/personal.yaml";
        owner = username;
        path = "/home/${username}/.config/sops/age/keys.txt";
        mode = "0600";
      };
    };
}
