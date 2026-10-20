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

            # tailscaled 1.104 rejects the NotifyInitialNetMap and NotifyRateLimit bits with 400.
            # Use the upstream mask from DMS commit 5113441 until nixpkgs ships a fixed release.
            substituteInPlace internal/server/tailscale/manager.go \
              --replace-fail 'ipn.NotifyInitialNetMap | ipn.NotifyRateLimit' \
              'ipn.NotifyPeerChanges | ipn.NotifyPeerPatches'
          '';
        });
      })
    ];
  };
}
