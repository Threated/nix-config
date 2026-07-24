{ config, lib, ... }:
let
  normal = {
    black = "#1E2127";
    red = "#E06C75";
    green = "#98C379";
    yellow = "#D19A66";
    blue = "#61AFEF";
    magenta = "#C678DD";
    cyan = "#56B6C2";
    white = "#ABB2BF";
  };
  bright = {
    black = "#5C6370";
    red = "#E06C75";
    green = "#98C379";
    yellow = "#D19A66";
    blue = "#61AFEF";
    magenta = "#C678DD";
    cyan = "#56B6C2";
    white = "#FFFEFE";
  };
  ansi = with normal; [
    black
    red
    green
    yellow
    blue
    magenta
    cyan
    white
  ];
  brights = with bright; [
    black
    red
    green
    yellow
    blue
    magenta
    cyan
    white
  ];
in
{
  options.theme = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    description = "Shared application color theme.";
  };

  config = {
    theme = {
      name = "Ghostty";
      background = "#1E2127";
      foreground = "#5C6370";
      cursor = "#5C6370";
      cursorText = "#1E2127";
      selectionBackground = "#5C6370";
      selectionForeground = "#FFFEFE";
      inherit normal bright;
      inherit ansi brights;

      # Semantic roles used by graphical shells and the greeter.
      semantic = {
        primary = normal.blue;
        onPrimary = "#1E2127";
        secondary = normal.yellow;
        onSecondary = "#1E2127";
        tertiary = normal.green;
        onTertiary = "#1E2127";
        error = normal.red;
        onError = "#1E2127";
        surface = "#1E2127";
        onSurface = "#8790a1";
        surfaceVariant = normal.black;
        onSurfaceVariant = normal.white;
        outline = bright.black;
        shadow = normal.black;
        hover = normal.cyan;
        onHover = "#1E2127";
      };
    };

    flake.lib.theme = config.theme;
  };
}
