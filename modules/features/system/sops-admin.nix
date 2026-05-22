{
  config,
  lib,
  inputs,
  username,
  ...
}:
let
  hasSecrets = inputs ? nixos-secrets;
  secretsPath = if hasSecrets then "${inputs.nixos-secrets}/secrets" else null;
in
lib.mkIf config.features.sops-admin.enable {
  sops.secrets."age-secret" = {
    sopsFile = "${secretsPath}/personal.yaml";
    owner = username;
    path = "/home/${username}/.config/sops/age/keys.txt";
    mode = "0600";
  };
}
