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
          workConfig = (import "${inputs.nixos-work}") { inherit username; };
        in
        {
          config = lib.mkIf config.hostSecrets.available (workConfig.${attr} or { });
        };
    in
    {
      work-github = mkWork "github";
      work-cloud = mkWork "cloud";
      work-servers = mkWork "servers";
    };
}
