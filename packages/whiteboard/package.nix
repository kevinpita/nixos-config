{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  alsa-lib,
  at-spi2-atk,
  cairo,
  cups,
  dbus,
  expat,
  gtk3,
  libarchive,
  libdrm,
  libgbm,
  libglvnd,
  libkrb5,
  libsecret,
  libxkbcommon,
  nspr,
  nss,
  pango,
  systemd,
  xorg,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "whiteboard";
  version = "0.1.2";

  # Prebuilt upstream release; bump version and hash manually.
  src = fetchurl {
    url = "https://github.com/devdotfast/whiteboard/releases/download/v${finalAttrs.version}/dev-fast-review-${finalAttrs.version}-1.x86_64.rpm";
    hash = "sha256-XVu4de/c4dN7ZuLCQcUxXzCpA2E25iD1iUxTKaMbcfc=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    libarchive
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    cairo
    cups
    dbus
    expat
    gtk3
    libdrm
    libgbm
    libkrb5
    libsecret
    libxkbcommon
    nspr
    nss
    pango
    stdenv.cc.cc
    xorg.libX11
    xorg.libxcb
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libxkbfile
    xorg.libXrandr
  ];

  runtimeDependencies = [
    libglvnd
    (lib.getLib systemd)
  ];

  unpackPhase = ''
    runHook preUnpack
    bsdtar -xf $src
    runHook postUnpack
  '';

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share
    cp -r usr/share/review usr/share/icons usr/share/metainfo usr/share/applications $out/share/
    rm $out/share/review/chrome-sandbox

    makeWrapper $out/share/review/review $out/bin/review-desktop \
      --unset ELECTRON_RUN_AS_NODE \
      --unset VSCODE_DEV \
      --unset VSCODE_CLI \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libglvnd ]} \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}"

    makeWrapper $out/share/review/review $out/bin/whiteboard \
      --set ELECTRON_RUN_AS_NODE 1 \
      --set DEV_FAST_REVIEW_DESKTOP_COMMAND $out/bin/review-desktop \
      --add-flags $out/share/review/resources/app/review-runtime/dist/cli.js

    substituteInPlace $out/share/applications/*.desktop \
      --replace-fail /usr/bin/review-desktop $out/bin/review-desktop

    runHook postInstall
  '';

  meta = {
    description = "Open-source canvas for thoughtful software design";
    homepage = "https://github.com/devdotfast/whiteboard";
    changelog = "https://github.com/devdotfast/whiteboard/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "review-desktop";
    platforms = [ "x86_64-linux" ];
  };
})
