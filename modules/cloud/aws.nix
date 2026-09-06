{
  flake.modules.nixos.aws =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        # AWS clients and authentication
        aws-iam-authenticator
        awscli2

        # Infrastructure provisioning
        terraform
      ];
    };
}
