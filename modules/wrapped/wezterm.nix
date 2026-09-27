{ inputs, ... }: {
  perSystem = { pkgs, ... }: {
    packages.wezterm = inputs.wrapper-modules.wrappers.wezterm.wrap {
      inherit pkgs;
      "wezterm.lua".content = ''
        local wezterm = require 'wezterm'

        return {
          font = wezterm.font("JetBrains Mono"),
          font_size = 16.0,
          color_scheme = "One Dark (Gogh)",
          hide_tab_bar_if_only_one_tab = true,
          keys = {
            {
              key = "Backspace",
              mods = "CTRL",
              action = wezterm.action.SendString "\x17",
            },
          },
        }
      '';
    };
  };
}
