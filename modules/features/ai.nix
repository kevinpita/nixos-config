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
    herdr
    pi-coding-agent

    rtk

    bubblewrap # codex dependency
    fd # pi dependency
  ];

  home-manager.users.${username} = {
    programs.zsh.shellAliases = {
      clauded = "claude --dangerously-skip-permissions";
    };
  };
}
