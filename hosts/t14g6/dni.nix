{
  inputs,
  pkgs,
  ...
}:
{
  imports = [ inputs.autofirma-nix.nixosModules.autofirma ];

  services.pcscd.enable = true;

  environment.systemPackages = with pkgs; [
    opensc
    pcsc-tools
  ];

  programs = {
    autofirma = {
      enable = true;
      firefoxIntegration.enable = true;
      package = inputs.autofirma-nix.packages.${pkgs.stdenv.hostPlatform.system}.autofirma.override {
        buildFHSEnv =
          args:
          pkgs.buildFHSEnv (
            args
            // {
              targetPkgs = fhsPkgs: args.targetPkgs fhsPkgs ++ [ fhsPkgs.pcsclite.lib ];
            }
          );
      };
    };

    firefox.policies.SecurityDevices."OpenSC PKCS#11" = "${pkgs.opensc}/lib/opensc-pkcs11.so";
  };
}
