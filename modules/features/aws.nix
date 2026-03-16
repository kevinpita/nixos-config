{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf config.features.aws.enable {
  environment.systemPackages = with pkgs; [
    awscli2
    aws-iam-authenticator
  ];
}
