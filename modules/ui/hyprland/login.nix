{
  flake.modules.nixos.hyprland =
    {
      username,
      ...
    }:
    let
      session = "uwsm start hyprland.desktop";
    in
    {
      services.greetd = {
        enable = true;
        settings = {
          initial_session = {
            command = session;
            user = username;
          };
          default_session = {
            command = session;
            user = username;
          };
        };
      };
    };
}
