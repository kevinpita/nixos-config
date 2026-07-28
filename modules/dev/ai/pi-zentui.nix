{
  flake.modules.nixos.ai =
    { username, ... }:
    {
      home-manager.users.${username}.home.file.".pi/agent/zentui.json" = {
        force = true;
        text = builtins.toJSON {
          # Preserve the ANSI colors emitted by these extensions.
          extensionStatuses.colorModes = {
            dictation = "original";
            fast-mode = "original";
          };
        };
      };
    };
}
