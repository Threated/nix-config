{ config, inputs, ... }:
let
  theme = config.theme;
  inherit (theme) semantic;
  terminal = {
    inherit (theme) background foreground cursor cursorText;
    selectionBg = theme.selectionBackground;
    selectionFg = theme.selectionForeground;
    inherit (theme) normal bright;
  };
  palette = {
    mPrimary = semantic.primary;
    mOnPrimary = semantic.onPrimary;
    mSecondary = semantic.secondary;
    mOnSecondary = semantic.onSecondary;
    mTertiary = semantic.tertiary;
    mOnTertiary = semantic.onTertiary;
    mError = semantic.error;
    mOnError = semantic.onError;
    mSurface = semantic.surface;
    mOnSurface = semantic.onSurface;
    mSurfaceVariant = semantic.surfaceVariant;
    mOnSurfaceVariant = semantic.onSurfaceVariant;
    mOutline = semantic.outline;
    mShadow = semantic.shadow;
    mHover = semantic.hover;
    mOnHover = semantic.onHover;
    inherit terminal;
  };
in
{
  perSystem =
    { pkgs, ... }:
    let
      ghosttyPalette = {
        dark = palette;
        light = palette;
      };

      configToml = ./noctalia.toml;
      wallpaperDirectory = ./../../assets/wallpapers;
      wallpaperToml = (pkgs.formats.toml { }).generate "wallpaper.toml" {
        wallpaper = {
          enabled = true;
          directory = "${wallpaperDirectory}";
          fill_mode = "crop";
          transition_on_startup = false;
          default.path = "${wallpaperDirectory}/raindbow-nix.png";
        };
      };
      paletteJson = (pkgs.formats.json { }).generate "${theme.name}.json" ghosttyPalette;
      configHome = pkgs.runCommand "noctalia-config" { } ''
        install -Dm644 ${configToml} "$out/noctalia/config.toml"
        install -Dm644 ${wallpaperToml} "$out/noctalia/wallpaper.toml"
        install -Dm644 ${paletteJson} "$out/noctalia/palettes/${theme.name}.json"
      '';
    in
    {
      packages.noctalia = inputs.wrapper-modules.lib.wrapPackage {
        inherit pkgs;
        package = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
        runtimePkgs = [
          inputs.noctalia-greeter.packages.${pkgs.stdenv.hostPlatform.system}.default
        ];
        env.NOCTALIA_CONFIG_HOME = configHome;
      };
    };
}
