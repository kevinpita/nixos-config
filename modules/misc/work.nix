{
  flake.modules.nixos =
    let
      mkWork =
        attr:
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
          config = lib.mkIf (hasWork && config.hostSecrets.enable) (workConfig.${attr} or { });
        };
    in
    {
      work-github = mkWork "github";
      work-cloud = mkWork "cloud";
    };
}
