{
  config,
  lib,
  username,
  ...
}:
lib.mkIf config.features.ssh-server.enable {
  programs.ssh = {
    startAgent = true;
    extraConfig = ''
      Host github.com
        IdentityFile /home/${username}/.ssh/id_ed25519
    '';
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };
}
