{
  flake.modules.nixos.hyprland = {
    nixpkgs.overlays = [
      (_: prev: {
        dms-shell = prev.dms-shell.overrideAttrs (old: {
          # Patch the QML sources before preBuild embeds them in the DMS binary.
          postPatch = (old.postPatch or "") + ''
            chmod -R u+w ../quickshell
            patch -d .. -p1 < ${../../hyprland/patches/workspace-switcher-drag-reorder.patch}

            substituteInPlace ../quickshell/Modules/ControlCenter/BuiltinPlugins/TailscaleWidget.qml \
              --replace-fail 'color: peerMouseArea.containsMouse ? Theme.primaryHoverLight : Theme.surfaceLight' \
              'color: peerMouseArea.containsMouse ? Theme.primaryContainer : Theme.surfaceContainerHighest'
          '';
        });
      })
    ];
  };
}
