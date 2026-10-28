{
  flake.modules.nixos.dni =
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
              maven-dependencies-hash = "sha256-l+6+EcMjEpyMQXFZ1xmqAPLDU7W3NssnLGOPizD9Suc=";
              jmulticard = upstreamAutofirma.clienteafirma.dependencies.jmulticard.override {
                maven-dependencies-hash = "sha256-b3eiMC8Ub4UyNcKGl2QDC/GMJda99U36Yw/6SAZhoBE=";
              };
              clienteafirma-external =
                upstreamAutofirma.clienteafirma.dependencies.clienteafirma-external.override
                  {
                    maven-dependencies-hash = "sha256-ZgctMSDqg/KNA64wi2vcF7a2n5GWnpy3wDwWoK3Cxbk=";
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
    };
}
