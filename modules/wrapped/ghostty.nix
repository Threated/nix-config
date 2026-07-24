{ config, inputs, ... }:
let
  theme = config.theme;
in
{
  perSystem = { pkgs, ... }: {
    packages.ghostty = inputs.wrapper-modules.lib.wrapPackage {
      inherit pkgs;
      package = pkgs.ghostty;
      flagSeparator = "=";
      flags."--config-file" = pkgs.writeText "ghostty-config" ''
        window-decoration = none
        background = ${theme.background}
        foreground = ${theme.foreground}
        cursor-color = ${theme.cursor}
        font-family = JetBrainsMono Nerd Font
        font-style = Regular
        font-synthetic-style = false
        adjust-cell-height = 2
        ${builtins.concatStringsSep "\n" (
          builtins.genList (index: "palette = ${toString index}=${builtins.elemAt (theme.ansi ++ theme.brights) index}") 16
        )}
        window-padding-x = 8,4
        window-padding-y = 2
        font-size = 16
      '';
    };
  };
}
