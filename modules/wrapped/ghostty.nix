{ inputs, ... }: {
  perSystem = { pkgs, ... }: {
    packages.ghostty = inputs.wrapper-modules.lib.wrapPackage {
      inherit pkgs;
      package = pkgs.ghostty;
      flagSeparator = "=";
      flags."--config-file" = pkgs.writeText "ghostty-config" ''
        window-decoration = none
        background = #1E2127
        foreground = #5C6370
        cursor-color = #5C6370
        font-family = JetBrainsMono Nerd Font
        font-style = Regular
        font-synthetic-style = false
        adjust-cell-height = 2
        palette = 0=#000000
        palette = 1=#E06C75
        palette = 2=#98C379
        palette = 3=#D19A66
        palette = 4=#61AFEF
        palette = 5=#C678DD
        palette = 6=#56B6C2
        palette = 7=#ABB2BF
        palette = 8=#5C6370
        palette = 9=#E06C75
        palette = 10=#98C379
        palette = 11=#D19A66
        palette = 12=#61AFEF
        palette = 13=#C678DD
        palette = 14=#56B6C2
        palette = 15=#FFFEFE
        window-padding-x = 8,4
        window-padding-y = 2
        font-size = 16
      '';
    };
  };
}
