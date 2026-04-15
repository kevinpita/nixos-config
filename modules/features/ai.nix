{
  config,
  lib,
  pkgs,
  username,
  ...
}:
lib.mkIf config.features.ai.enable {
  environment.systemPackages = with pkgs; [
    codex
    claude-code
    gemini-cli
    bubblewrap # codex dependency
    rtk
  ];

  home-manager.users.${username} = {
    programs.zsh.shellAliases = {
      clauded = "claude --dangerously-skip-permissions";
    };
  };
}
