{
  flake.modules.nixos.vscode =
    { pkgs, username, ... }:
    {
      home-manager.users.${username}.programs.vscode = {
        enable = true;
        # FHS environment lets marketplace extensions run their bundled binaries
        package = pkgs.vscode.fhs;
        # Allow VS Code to install and update extensions in ~/.vscode/extensions
        mutableExtensionsDir = true;
      };
    };
}
