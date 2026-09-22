{
  flake.modules.nixos.ai =
    { pkgs, username, ... }:
    {
      environment.systemPackages = [ pkgs.antigravity-cli ];

      home-manager.users.${username}.programs.zsh.shellAliases.agy = "agy --dangerously-skip-permissions";
    };
}
