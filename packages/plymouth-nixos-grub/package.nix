{
  imagemagick,
  grubTheme,
  stdenvNoCC,
  ubuntu-classic,
}:

stdenvNoCC.mkDerivation {
  pname = "plymouth-nixos-grub";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [ imagemagick ];

  buildPhase = ''
    runHook preBuild
    bash make-backgrounds.sh ${grubTheme}/background.png \
      ${ubuntu-classic}/share/fonts/truetype/ubuntu backgrounds
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    theme=$out/share/plymouth/themes/nixos-grub
    install -Dm644 -t $theme backgrounds/*.png nixos-grub.script \
      ${grubTheme}/select_w.png ${grubTheme}/select_c.png ${grubTheme}/select_e.png \
      ${grubTheme}/icons/nixos.png
    substitute nixos-grub.plymouth $theme/nixos-grub.plymouth --subst-var theme
    runHook postInstall
  '';
}
