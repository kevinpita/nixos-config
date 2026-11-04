# Desktop theme palettes from themes/<name>/theme.toml, shared by the
# Hyprland theme switcher and by hosts without a desktop.
{ inputs, lib }:
rec {
  names = builtins.attrNames (builtins.readDir ../themes);

  paletteOf = name: builtins.fromTOML (builtins.readFile ../themes/${name}/theme.toml);

  # Terminal colors 0-15, shared by ghostty and omp.
  ansiColors = theme: [
    theme.background
    theme.red
    theme.green
    theme.yellow
    theme.blue
    theme.magenta
    theme.cyan
    theme.foreground
    theme.muted
    theme.bright_red
    theme.bright_green
    theme.bright_yellow
    theme.bright_blue
    theme.bright_magenta
    theme.bright_cyan
    theme.bright_foreground
  ];

  # omp's titanium theme with its colors taken from the palette. Answer
  # text is brighter than thinking text. New titanium color keys still
  # arrive with omp updates.
  ompTheme =
    theme:
    lib.recursiveUpdate
      (lib.importJSON "${inputs.oh-my-pi}/packages/tui/src/theme/defaults.json").titanium
      {
        name = "desktop";
        vars = {
          brushedTitanium = theme.background;
          darkTitanium = theme.dark_background;
          subtleGray = theme.lighter_background;
          electricBlue = theme.accent;
          deepBlue = theme.blue;
          titaniumGold = theme.yellow;
          brightAluminum = theme.bright_foreground;
          dimAluminum = theme.dark_foreground;
          warningAmber = theme.bright_yellow;
          readoutGreen = theme.bright_green;
          alertRed = theme.bright_red;
        };
        colors = {
          assistantMessageText = "brightAluminum";
          thinkingText = theme.muted;
          mdCode = theme.bright_cyan;
          mdCodeBlockBorder = theme.selection;
          mdQuoteBorder = theme.selection;
          mdHr = theme.selection;
          mdListBullet = "deepBlue";
          # titanium writes these as hex instead of vars.
          borderMuted = theme.lighter_background;
          dim = theme.muted;
          syntaxComment = theme.muted;
          toolErrorBg = theme.darker_background;
          thinkingOff = theme.selection;
          thinkingMinimal = theme.selection;
          thinkingLow = theme.muted;
          pythonMode = theme.bright_yellow;
        };
        terminal = {
          inherit (theme) background foreground;
          chrome = theme.dark_background;
          widget = theme.lighter_background;
          ansi = ansiColors theme;
        };
      };
}
