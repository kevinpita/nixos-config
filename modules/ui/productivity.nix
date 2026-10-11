{
  flake.modules.nixos.productivity =
    { pkgs, username, ... }:
    {
      home-manager.users.${username} = {
        home.packages = [
          pkgs.heynote
          pkgs.obsidian
          pkgs.sioyek
        ];

        xdg.mimeApps.defaultApplications = {
          "application/pdf" = "sioyek.desktop";
          "x-scheme-handler/notion" = "notion-app-enhanced.desktop";
        };
      };
    };
}
