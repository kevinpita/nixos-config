{
  flake.modules.nixos.printing-3d =
    {
      config,
      lib,
      pkgs,
      username,
      ...
    }:
    let
      # Orca writes its user presets here; links keep them in this repository.
      orcaPresets = "${config.programs.nh.flake}/orca-slicer";
    in
    {
      home-manager.users.${username} =
        { config, ... }:
        {
          home.packages = with pkgs; [
            # Orca 2.4.2 segfaults rendering plate thumbnails when WebKitGTK 2.54 leaves its GL
            # context current (OrcaSlicer#15810). Remove after the next Orca release, which includes the fix (#15873).
            (symlinkJoin {
              name = "orca-slicer";
              paths = [ orca-slicer ];
              buildInputs = [ makeWrapper ];
              postBuild = ''
                wrapProgram $out/bin/orca-slicer \
                  --set WEBKIT_DISABLE_DMABUF_RENDERER 1 \
                  --set GALLIUM_THREAD 0
              '';
            })
            prusa-slicer
            super-slicer-beta
          ];

          xdg.configFile = lib.genAttrs' [ "machine" "process" "filament" ] (
            kind:
            lib.nameValuePair "OrcaSlicer/user/default/${kind}" {
              source = config.lib.file.mkOutOfStoreSymlink "${orcaPresets}/${kind}";
            }
          );
        };
    };
}
