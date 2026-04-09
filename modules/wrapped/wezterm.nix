{ inputs, ... }:
{
  perSystem =
    {
      pkgs,
      ...
    }:
    {
      packages.wezterm = inputs.wrapper-modules.wrappers.wezterm.wrap {
        inherit pkgs;
        "wezterm.lua".content = ''
          local wezterm = require 'wezterm'

          local xcursor_size = nil
          local xcursor_theme = nil

          local success, stdout, stderr = wezterm.run_child_process({"gsettings", "get", "org.gnome.desktop.interface", "cursor-theme"})
          if success then
            xcursor_theme = stdout:gsub("'(.+)'\n", "%1")
          end

          local success, stdout, stderr = wezterm.run_child_process({"gsettings", "get", "org.gnome.desktop.interface", "cursor-size"})
          if success then
            xcursor_size = tonumber(stdout)
          end
          return {
            font = wezterm.font("JetBrains Mono"),
            font_size = 16.0,
            color_scheme = "One Dark (Gogh)",
            hide_tab_bar_if_only_one_tab = true,
            xcursor_theme = xcursor_theme,
            xcursor_size = xcursor_size,
          }
        '';
      };
    };
}
