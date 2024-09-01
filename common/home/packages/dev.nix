{ pkgs, ... }:
{
  imports = [ ../programs/vscode.nix ];
  home.packages = with pkgs; [ jetbrains.goland ];
}
