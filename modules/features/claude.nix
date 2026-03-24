{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf config.features.claude.enable {
  environment.systemPackages = with pkgs; [
    claude-code
    rtk
  ];
}
