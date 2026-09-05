{
  flake.modules.nixos =
    let
      mkWork =
        attr:
        {
          ciMode,
          lib,
          workConfig,
          ...
        }:
        {
          config = lib.mkIf (!ciMode) workConfig.${attr};
        };
    in
    {
      work-github = mkWork "github";
      work-cloud = mkWork "cloud";
      work-servers = mkWork "servers";
    };
}
