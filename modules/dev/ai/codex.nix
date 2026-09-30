{
  flake.modules.nixos.ai =
    { pkgs, username, ... }:
    {
      environment.systemPackages = with pkgs; [
        bubblewrap # codex dependency
        codex
      ];

      home-manager.users.${username}.programs.zsh.shellAliases.codex =
        "codex --dangerously-bypass-approvals-and-sandbox";
    };

}
