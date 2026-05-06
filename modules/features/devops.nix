{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf config.features.devops.enable {
  environment.systemPackages = with pkgs; [
    wrkflw
  ];
}
