{
  flake.modules.nixos.ai =
    { pkgs, username, ... }:
    {
      environment.systemPackages = with pkgs; [
        bubblewrap # codex dependency
        codex
      ];

      home-manager.users.${username}.programs.zsh.shellAliases.codex =
        "codex --dangerously-bypass-approvals-and-sandbox --model gpt-6.1-sol -c model_reasoning_effort=medium";
    };

}
