{
  flake.modules.nixos.productivity =
    { pkgs, username, ... }:
    {
      home-manager.users.${username} = {
        home.packages = [
          pkgs.heynote
          pkgs.obsidian
        ];

        xdg.mimeApps.defaultApplications."x-scheme-handler/notion" = "notion-app-enhanced.desktop";
      };
    };
}
