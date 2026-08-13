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
      package =
        let
          upstreamAutofirma = inputs.autofirma-nix.packages.${pkgs.stdenv.hostPlatform.system}.autofirma;
        in
        upstreamAutofirma.override {
          maven-dependencies-hash = "sha256-aNtvfZuu84dS3/ZvbuVlmt2ELQFHr0OtNABnDo/Hdp4=";
          jmulticard = upstreamAutofirma.clienteafirma.dependencies.jmulticard.override {
            maven-dependencies-hash = "sha256-2lUqrN8s0KTbk8wd76FkU5wgaPZnzmpO9rgTE6Oe+os=";
          };

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
