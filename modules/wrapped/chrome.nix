{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.chrome = inputs.wrapper-modules.lib.wrapPackage {
        inherit pkgs;
        package = pkgs.google-chrome;
        flagSeparator = "=";
        flags = {
          "--enable-features" = "UseOzonePlatform,TouchpadOverscrollHistoryNavigation";
          "--ozone-platform" = "wayland";
        };
      };
    };
}
