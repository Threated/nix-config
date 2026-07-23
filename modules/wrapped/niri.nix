{ self, inputs, ... }: {
  flake.nixosModules.niri = { pkgs, lib, ... }: {
    imports = [ inputs.noctalia-greeter.nixosModules.default ];

    programs.niri = {
      enable = true;
      package = self.packages.${pkgs.stdenv.hostPlatform.system}.niri;
    };

    programs.noctalia-greeter = {
      enable = true;
      # Noctalia currently hard-codes the login panel width. Keep a small
      # local patch until upstream exposes this as a setting. The same patch
      # guards keyboard callbacks during compositor teardown; without it the
      # current upstream revision coredumps after a successful login.
      package =
        inputs.noctalia-greeter.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs
          (old: {
            patches = (old.patches or [ ]) ++ [
              (pkgs.writeText "noctalia-greeter-local.patch" ''
                diff --git a/src/compositor/noctalia_compositor.c b/src/compositor/noctalia_compositor.c
                --- a/src/compositor/noctalia_compositor.c
                +++ b/src/compositor/noctalia_compositor.c
                @@ -1477,4 +1477,7 @@ static void focus_mapped_views(struct greeter_server* server) {
                 static void handle_keyboard_modifiers(struct wl_listener* listener, void* data) {
                   (void)data;
                   struct greeter_keyboard* keyboard = wl_container_of(listener, keyboard, modifiers);
                +  if (keyboard->server->shutting_down) {
                +    return;
                +  }
                   wlr_seat_keyboard_notify_modifiers(keyboard->server->seat, &keyboard->wlr_keyboard->modifiers);
                @@ -1483,4 +1486,7 @@ static void handle_keyboard_modifiers(struct wl_listener* listener, void* data) {
                 static void handle_keyboard_key(struct wl_listener* listener, void* data) {
                   struct greeter_keyboard* keyboard = wl_container_of(listener, keyboard, key);
                   struct greeter_server* server = keyboard->server;
                +  if (server->shutting_down) {
                +    return;
                +  }
                   struct wlr_keyboard_key_event* event = data;
                diff --git a/src/greeter/greeter_surface.cpp b/src/greeter/greeter_surface.cpp
                --- a/src/greeter/greeter_surface.cpp
                +++ b/src/greeter/greeter_surface.cpp
                @@ -1019 +1019 @@ void GreeterSurface::updateLayout() {
                -  const float panelWidth = std::clamp(sw * 0.32f, Style::scaled(440.0f), Style::scaled(540.0f));
                +  const float panelWidth = std::clamp(sw * 0.28f, Style::scaled(380.0f), Style::scaled(460.0f));
              '')
            ];
          });
      greeter-args = "--session niri";
      settings = {
        appearance = {
          hide_logo = true;
          scheme = "Tokyo-Night";
        };
        keyboard = {
          layout = "de";
          numlock = true;
        };
      };
    };

    # VT 1 contains the boot log. A dedicated, initially blank VT prevents it
    # from flashing while the greeter compositor hands DRM over to niri.
    services.greetd.settings.terminal.vt = lib.mkForce 7;
    services.upower.enable = true;
  };
  perSystem = { pkgs, lib, self', ... }: {
    packages.niri = inputs.wrapper-modules.wrappers.niri.wrap {
      inherit pkgs;
      settings = {
        spawn-at-startup = [
          (lib.getExe self'.packages.noctalia)
          (lib.getExe (pkgs.writeShellScriptBin "wallpaper" ''
            exec ${lib.getExe pkgs.swaybg} \
              -i ${pkgs.nixos-artwork.wallpapers.simple-dark-gray.gnomeFilePath} \
              -m fill
          ''))
        ];

        hotkey-overlay.skip-at-startup = true;

        input.keyboard.xkb.layout = "de";
        input.keyboard.xkb.options = "ctrl:nocaps";
        input.keyboard.numlock = true;
        input.touchpad.tap = [ ];
        input.touchpad.natural-scroll = [ ];

        layout = {
          gaps = 5;
          focus-ring = {
            width = 2;
            active-color = "#7aa2f780";
            inactive-color = "#565f8980";
          };
        };

        binds = {
          "Mod+Return".spawn-sh = lib.getExe self'.packages.wezterm;
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
            "${lib.getExe self'.packages.noctalia} ipc call lockScreen lock";

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
          "Print".screenshot = { };
          "Ctrl+Print".screenshot-screen = { };
          "Alt+Print".screenshot-window = { };

          "Mod+Space".spawn-sh =
            "${lib.getExe self'.packages.noctalia} ipc call launcher toggle";
        };
      };
    };
  };
}
