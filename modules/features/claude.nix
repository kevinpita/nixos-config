{
  config,
  lib,
  pkgs,
  username,
  ...
}:
lib.mkIf config.features.claude.enable {
  environment.systemPackages = with pkgs; [
    claude-code
    rtk
  ];

  home-manager.users.${username} = {
    programs.zsh.shellAliases = {
      clauded = "claude --dangerously-skip-permissions";
    };
  };
}
