{
  flake.modules.nixos.work =
    {
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
      config = lib.mkIf hasWork workConfig;
    };
}
