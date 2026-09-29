{ self, config, inputs, ... }:
let
  theme = config.theme;
in
{
  flake.nixosModules.niri = { pkgs, lib, ... }:
  let
    wallpaper = ./../../assets/wallpapers/raindbow-nix.png;
  in
  {

    imports = [ inputs.noctalia-greeter.nixosModules.default ];

    programs.niri = {
      enable = true;
      package = self.packages.${pkgs.stdenv.hostPlatform.system}.niri;
    };

    # Niri launches xwayland-satellite on demand for applications that still
    # use X11 APIs alongside their native Wayland windows (such as Discord).
    environment.systemPackages = [ pkgs.xwayland-satellite ];

    services.displayManager.noctalia-greeter = {
      enable = true;
      settings = {
        # Hosts can override this through the greeter's settings options.
        session.default = lib.mkDefault "niri";
        appearance = {
          hide_logo = true;
          scheme = "Synced";
        };
        keyboard = {
          layout = "de";
          numlock = true;
        };
      };
    };

    # The greeter runs before Noctalia and otherwise retains the wallpaper that
    # happened to be copied during its initial appearance sync. Point its cached
    # wallpaper at the declarative wallpaper so it cannot become stale.
    systemd.tmpfiles.settings."10-noctalia-greeter" =
      let
        inherit (theme) semantic;
        appearance = pkgs.writeText "noctalia-greeter-appearance.json" (
          builtins.toJSON {
            version = 1;
            theme_mode = "dark";
            palette = {
              inherit (semantic)
                primary
                secondary
                tertiary
                error
                surface
                outline
                shadow
                hover
                ;
              on_primary = semantic.onPrimary;
              on_secondary = semantic.onSecondary;
              on_tertiary = semantic.onTertiary;
              on_error = semantic.onError;
              on_surface = semantic.onSurface;
              surface_variant = semantic.surfaceVariant;
              on_surface_variant = semantic.onSurfaceVariant;
              on_hover = semantic.onHover;
            };
          }
        );
      in
      {
        "/var/lib/noctalia-greeter/appearance.json"."L+" = {
          argument = toString appearance;
        };
        "/var/lib/noctalia-greeter/wallpaper.png"."L+" = {
          argument = toString wallpaper;
        };
      };

    # VT 1 contains the boot log. A dedicated, initially blank VT prevents it
    # from flashing while the greeter compositor hands DRM over to niri.
    services.greetd.settings.terminal.vt = lib.mkForce 7;
    services.upower.enable = true;

    # Noctalia's brightness actions use the kernel backlight. This udev rule
    # grants users in the video group access to that device.
    services.udev.packages = [ pkgs.brightnessctl ];
  };
  perSystem = { pkgs, lib, self', ... }: {
    packages.niri =
      let
        noctalia = lib.getExe self'.packages.noctalia;
        # Give directly spawned desktop apps XDG-style systemd scopes so
        # process monitors can associate their cgroups with desktop entries.
        appScopeCommand =
          appId: command:
          "exec ${lib.getExe' pkgs.systemd "systemd-run"}"
          + " --user --scope --collect --quiet"
          + " --unit=app-${appId}-$(${lib.getExe' pkgs.systemd "systemd-id128"} new).scope"
          + " -- ${lib.escapeShellArgs command}";
      in
      inputs.wrapper-modules.wrappers.niri.wrap {
      inherit pkgs;
      settings = {
        spawn-sh-at-startup = [
          (appScopeCommand "dev.noctalia.Noctalia" [ noctalia ])
        ];

        hotkey-overlay.skip-at-startup = true;

        input.keyboard.xkb.layout = "de";
        input.keyboard.xkb.options = "ctrl:nocaps";
        input.keyboard.numlock = true;
        input.touchpad.tap = [ ];
        input.touchpad.natural-scroll = [ ];

        layout = {
          background-color = "transparent";
          gaps = 5;
          focus-ring = {
            width = 2;
            active-color = "${theme.normal.blue}80";
            inactive-color = "${theme.bright.black}80";
          };
        };

        layer-rules = [
          {
            matches = [ { namespace = "^noctalia-wallpaper"; } ];
            place-within-backdrop = true;
          }
        ];

        binds = {
          "Mod+Return".spawn-sh = appScopeCommand "org.wezfurlong.wezterm" [
            (lib.getExe self'.packages.wezterm)
          ];
          "Mod+D".close-window = { };
          "Mod+Q".close-window = { };

          "Mod+H".focus-column-or-monitor-left = { };
          "Mod+Left".focus-column-or-monitor-left = { };
          "Mod+L".focus-column-or-monitor-right = { };
          "Mod+Right".focus-column-or-monitor-right = { };
          "Mod+K".focus-window-up = { };
          "Mod+Up".focus-window-up = { };
          "Mod+J".focus-window-down = { };
          "Mod+Down".focus-window-down = { };

          "Mod+Ctrl+L".spawn-sh =
            "${lib.getExe self'.packages.noctalia} msg session lock";

          # Workspaces.
          "Mod+1".focus-workspace = 1;
          "Mod+2".focus-workspace = 2;
          "Mod+3".focus-workspace = 3;
          "Mod+4".focus-workspace = 4;
          "Mod+5".focus-workspace = 5;
          "Mod+6".focus-workspace = 6;
          "Mod+7".focus-workspace = 7;
          "Mod+8".focus-workspace = 8;
          "Mod+9".focus-workspace = 9;
          "Mod+Tab".focus-workspace-previous = { };
          "Mod+U".focus-workspace-down = { };
          "Mod+I".focus-workspace-up = { };

          "Mod+Ctrl+1".move-column-to-workspace = 1;
          "Mod+Ctrl+2".move-column-to-workspace = 2;
          "Mod+Ctrl+3".move-column-to-workspace = 3;
          "Mod+Ctrl+4".move-column-to-workspace = 4;
          "Mod+Ctrl+5".move-column-to-workspace = 5;
          "Mod+Ctrl+6".move-column-to-workspace = 6;
          "Mod+Ctrl+7".move-column-to-workspace = 7;
          "Mod+Ctrl+8".move-column-to-workspace = 8;
          "Mod+Ctrl+9".move-column-to-workspace = 9;

          "Mod+Shift+H".move-column-left-or-to-monitor-left = { };
          "Mod+Shift+Left".move-column-left-or-to-monitor-left = { };
          "Mod+Shift+L".move-column-right-or-to-monitor-right = { };
          "Mod+Shift+Right".move-column-right-or-to-monitor-right = { };
          "Mod+Shift+K".move-window-up-or-to-workspace-up = { };
          "Mod+Shift+Up".move-window-up-or-to-workspace-up = { };
          "Mod+Shift+J".move-window-down-or-to-workspace-down = { };
          "Mod+Shift+Down".move-window-down-or-to-workspace-down = { };

          # Column layout and sizing.
          "Mod+BracketLeft".consume-or-expel-window-left = { };
          "Mod+BracketRight".consume-or-expel-window-right = { };
          "Mod+Comma".consume-window-into-column = { };
          "Mod+Period".expel-window-from-column = { };
          "Mod+R".switch-preset-column-width = { };
          "Mod+Shift+R".switch-preset-column-width-back = { };
          "Mod+F".maximize-column = { };
          "Mod+Shift+F".fullscreen-window = { };
          "Mod+M".maximize-window-to-edges = { };
          "Mod+V".toggle-window-floating = { };
          "Mod+W".toggle-column-tabbed-display = { };
          "Mod+C".center-column = { };

          # Overview, help and screenshots.
          "Mod+O".toggle-overview = { };
          "Mod+Shift+Slash".show-hotkey-overlay = { };
          "Mod+Shift+S".spawn-sh = "${noctalia} msg screenshot-region";
          "Print".screenshot = { };
          "Ctrl+Print".screenshot-screen = { };
          "Alt+Print".screenshot-window = { };

          # Niri receives the physical keys; Noctalia performs the actions
          # and presents its audio/brightness OSD.
          "XF86AudioRaiseVolume".spawn-sh = "${noctalia} msg volume-up";
          "XF86AudioLowerVolume".spawn-sh = "${noctalia} msg volume-down";
          "XF86AudioMute".spawn-sh = "${noctalia} msg volume-mute";
          "XF86AudioMicMute".spawn-sh = "${noctalia} msg mic-mute";
          "XF86AudioPlay".spawn-sh = "${noctalia} msg media toggle";
          "XF86AudioPause".spawn-sh = "${noctalia} msg media pause";
          "XF86AudioStop".spawn-sh = "${noctalia} msg media stop";
          "XF86AudioNext".spawn-sh = "${noctalia} msg media next";
          "XF86AudioPrev".spawn-sh = "${noctalia} msg media previous";
          "XF86MonBrightnessUp".spawn-sh = "${noctalia} msg brightness-up";
          "XF86MonBrightnessDown".spawn-sh = "${noctalia} msg brightness-down";

          "Mod+Space".spawn-sh =
            "${noctalia} msg panel-toggle launcher";
        };
      };
    };
  };
}
