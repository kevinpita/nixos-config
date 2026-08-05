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
    };

    firefox.policies.SecurityDevices."OpenSC PKCS#11" = "${pkgs.opensc}/lib/opensc-pkcs11.so";
  };
}
