{
  lib,
  stdenv,
  fetchurl,

  # hooks
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,

  # native build inputs
  asar,
  dpkg,

  # build inputs
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  gdk-pixbuf,
  glib,
  gtk3,
  libdrm,
  libgbm,
  libnotify,
  libuuid,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  libxtst,
  nspr,
  nss,
  pango,
  pipewire,
  systemdLibs,

  # runtime deps
  bubblewrap,
  libGL,
  libayatana-appindicator,
  libpulseaudio,
  libsecret,
  OVMF,
  openssh,
  qemu_kvm,
  socat,
  virtiofsd,
  vulkan-loader,
  xdg-utils,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "claude-desktop";
  version = "5.1231.2";

  # Newest entry in https://downloads.claude.ai/claude-desktop/apt/stable/dists/stable/main/binary-amd64/Packages
  src = fetchurl {
    url = "https://downloads.claude.ai/claude-desktop/apt/stable/pool/main/c/claude-desktop/claude-desktop_${finalAttrs.version}_amd64.deb";
    hash = "sha256-600Wya/wppY2bYhyj3T6VRNr58/ePB/jWvQGK0WVW28=";
  };

  strictDeps = true;
  __structuredAttrs = true;

  sourceRoot = "root";

  # Cowork looks for QEMU, UEFI firmware, and virtiofsd at Debian paths. It
  # derives the OVMF_VARS path from the OVMF_CODE path.
  postPatch = ''
    resources=usr/lib/claude-desktop/resources
    asar extract $resources/app.asar app
    substituteInPlace app/.vite/build/*.js \
      --replace-quiet '"/usr/bin/qemu-system-x86_64"' '"${qemu_kvm}/bin/qemu-system-x86_64"' \
      --replace-quiet '["/usr/share/OVMF/OVMF_CODE_4M.fd","/usr/share/OVMF/OVMF_CODE.fd"]' '["${OVMF.fd}/FV/OVMF_CODE.fd"]' \
      --replace-quiet '["/usr/libexec/virtiofsd","/usr/bin/virtiofsd"]' '["${lib.getExe virtiofsd}"]'
    patched=$(grep -lF '${qemu_kvm}/bin/qemu-system-x86_64' app/.vite/build/*.js)
    grep -qF '${OVMF.fd}/FV/OVMF_CODE.fd' "$patched"
    grep -qF '["${lib.getExe virtiofsd}"]' "$patched"
    # The V8 code cache of the patched file no longer matches its source.
    rm "app/compile-cache/$(basename "$patched").x64.jsc"
    rm $resources/app.asar
    asar pack app $resources/app.asar \
      --unpack-dir "{node_modules/@ant/claude-native,node_modules/node-pty,resources/github-mcp}"
  '';

  nativeBuildInputs = [
    asar
    autoPatchelfHook
    dpkg
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libgbm
    libnotify
    libuuid
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    libxtst
    nspr
    nss
    pango
    pipewire
    stdenv.cc.cc.lib
    systemdLibs
  ];

  runtimeDependencies = [
    libGL
    libayatana-appindicator
    libnotify
    libpulseaudio
    libsecret
    vulkan-loader
  ];

  dontWrapGApps = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp -r usr/lib usr/share $out
    rm -r $out/share/lintian
    # NixOS cannot install the setuid sandbox helper. Chromium uses user namespaces instead.
    rm $out/lib/claude-desktop/chrome-sandbox
    install -Dm644 $out/lib/claude-desktop/resources/linux-mime/com.anthropic.Claude.xml \
      $out/share/mime/packages/com.anthropic.Claude.xml
    # Cowork uses the bundled virtiofsd only on Ubuntu 22.04.
    rm $out/lib/claude-desktop/resources/virtiofsd

    runHook postInstall
  '';

  postFixup = ''
    makeWrapper $out/lib/claude-desktop/claude-desktop $out/bin/claude-desktop \
      "''${gappsWrapperArgs[@]}" \
      --suffix PATH : ${
        lib.makeBinPath [
          bubblewrap
          openssh
          socat
          xdg-utils
        ]
      }
  '';

  dontStrip = true;

  meta = {
    description = "Desktop application for Claude";
    homepage = "https://code.claude.com/docs/en/desktop-linux";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "claude-desktop";
  };
})
