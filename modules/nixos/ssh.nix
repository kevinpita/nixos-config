{ gui, ... }:
{
  programs.ssh = {
    startAgent = true;
    extraConfig = ''
      Host github.com
        IdentityFile ~/.ssh/id_ed25519
    '';
  };
  services.openssh = {
    enable = true;
    settings = {
      # Even though `!gui` is redundant, as this file is only included for non-GUI systems,
      # it's here for security reasons, ensuring password authentication is always disabled for gui systems.
      PasswordAuthentication = !gui;
      PermitRootLogin = "no";
    };
  };
}
