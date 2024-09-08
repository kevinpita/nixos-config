{ pkgs, ... }:

{
  home.packages = with pkgs; [
    virt-manager
    qemu
    OVMF
  ];
}
