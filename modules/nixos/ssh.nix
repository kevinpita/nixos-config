{ gui, ... }:
{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = !gui;
      PermitRootLogin = "no";
    };
  };
}
