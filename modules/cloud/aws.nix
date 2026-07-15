{
  flake.modules.nixos.aws =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        awscli2
        aws-iam-authenticator
      ];
    };
}
