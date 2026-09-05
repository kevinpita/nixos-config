{
  secrets,
  work,
  username,
}:
let
  isCi = path: builtins.pathExists "${path}/.nixos-config-ci";
  ciMode = isCi secrets;
  workConfig = (import work) { inherit username; };
  requiredWorkModules = [
    "github"
    "cloud"
    "servers"
  ];
in
if ciMode != isCi work then
  throw "Public CI requires both nixos-secrets and nixos-work dummy inputs; do not mix real and dummy inputs."
else if !ciMode && !builtins.pathExists "${secrets}/secrets/common.yaml" then
  throw "nixos-secrets must contain secrets/common.yaml. Use check-public for explicit dummy-input validation."
else if
  !builtins.isAttrs workConfig
  || !builtins.all (
    name: builtins.hasAttr name workConfig && builtins.isAttrs workConfig.${name}
  ) requiredWorkModules
then
  throw "nixos-work must return github, cloud, and servers module attribute sets."
else
  {
    inherit ciMode workConfig;
  }
