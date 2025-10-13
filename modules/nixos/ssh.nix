{
  lib,
  config,
  username,
  ...
}:
lib.mkIf (!config.gui.enable) {
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
      # Even though `!config.gui.enable` is redundant, as this file is only included for non-GUI systems,
      # it's here for security reasons, ensuring password authentication is always disabled for gui systems.
      PasswordAuthentication = !config.gui.enable;
      PermitRootLogin = "no";
    };
  };
}
