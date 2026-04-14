{
  config,
  lib,
  pkgs,
  username,
  ...
}:
lib.mkIf config.features.claude.enable {
  environment.systemPackages = with pkgs; [
    codex
    claude-code
    gemini-cli
    rtk
  ];

  home-manager.users.${username} = {
    programs.zsh.shellAliases = {
      clauded = "claude --dangerously-skip-permissions";
    };
  };
}
