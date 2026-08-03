{
  flake.modules.nixos.work =
    {
      config,
      lib,
      inputs,
      username,
      ...
    }:
    let
      hasWork = inputs ? nixos-work;
      workConfig = if hasWork then (import "${inputs.nixos-work}") { inherit username; } else { };
    in
    {
      config = lib.mkIf (hasWork && config.hostSecrets.enable) workConfig;
    };
}
