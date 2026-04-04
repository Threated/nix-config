{ self, inputs, ... }:
{

  # This is your standalone home-manager configuration, meant to be used on non-nixos machines
  # with the home-manager command
  flake.homeConfigurations.threated = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
    modules = [
      self.homeModules.base
      {
        home.username = "threated";
        home.homeDirectory = "/home/threated";
      }
    ];
  };

  # This is your home.nix, your module where you configure home-manager
  # It's imported both in standalone configuration above, and in your nixos configuration
  flake.homeModules.base =
    { pkgs, ... }:
    {
      # Home Manager needs a bit of information about you and the paths it should
      # manage.
      home.username = "threated";
      home.homeDirectory = "/home/threated";

      # This value determines the Home Manager release that your configuration is
      # compatible with. This helps avoid breakage when a new Home Manager release
      # introduces backwards incompatible changes.
      #
      # You should not change this value, even if you update Home Manager. If you do
      # want to update the value, then make sure to first check the Home Manager
      # release notes.
      home.stateVersion = "23.11";

      # The home.packages option allows you to install Nix packages into your
      # environment.
      home.packages = with pkgs; [
        # # It is sometimes useful to fine-tune packages, for example, by applying
        # # overrides. You can do that directly here, just don't forget the
        # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
        # # fonts?
        # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

        # # You can also create simple shell scripts directly inside your
        # # configuration. For example, this adds a command 'my-hello' to your
        # # environment:
        # (pkgs.writeShellScriptBin "my-hello" ''
        #   echo "Hello, ${config.home.username}!"
        # '')
        firefox
        (google-chrome.override {
          commandLineArgs = [
            "--enable-features=UseOzonePlatform"
            "--ozone-platform=wayland"
            "--enable-features=TouchpadOverscrollHistoryNavigation"
          ];
        })
        discord
        wezterm
        rustup
        mold
        openssl.dev
        pkg-config
        just
        nodejs
        clang
        jq
        zed-editor
        neovim
        gemini-cli
        codex
        nil
        nixd
        zulip
        gdb
        dolphin-emu
      ];

      # Home Manager is pretty good at managing dotfiles. The primary way to manage
      # plain files is through 'home.file'.
      home.file = {
        # # Building this configuration will create a copy of 'dotfiles/screenrc' in
        # # the Nix store. Activating the configuration will then make '~/.screenrc' a
        # # symlink to the Nix store copy.
        # ".screenrc".source = dotfiles/screenrc;

        # # You can also set the file content immediately.
        # ".gradle/gradle.properties".text = ''
        #   org.gradle.console=verbose
        #   org.gradle.daemon.idletimeout=3600000
        # '';
      };

      home.sessionVariables = {
        EDITOR = "vim";
      };
      # home-manager settings
      programs.git = {
        enable = true;
        signing.format = null;
        settings.user.name = "Threated";
        settings.user.email = "jan2001.07@gmail.com";
      };
      programs.jujutsu = {
        enable = true;
        settings = {
          user.name = "Threated";
          user.email = "jan2001.07@gmail.com";
          ui.editor = "vim";
          ui.default-command = "log";
        };
      };
      programs.wezterm.enable = true;
      programs.wezterm.extraConfig = ''
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
      programs.fish = {
        enable = true;
        shellAliases = {
          lsa = "ls -la";
          cat = "bat";
        };
        shellInit = ''
          set fish_greeting '''
          bind ctrl-h backward-kill-word
          bind ctrl-w backward-kill-word
          function nosleep
              set -l schema org.gnome.settings-daemon.plugins.power
              set -l old_ac (gsettings get $schema sleep-inactive-ac-type)
              set -l old_bat (gsettings get $schema sleep-inactive-battery-type)

              gsettings set $schema sleep-inactive-ac-type "'nothing'"
              gsettings set $schema sleep-inactive-battery-type "'nothing'"

              systemd-inhibit --what=idle:sleep --why="temporary no sleep" sleep infinity &
              set -l job (jobs --last --group)

              function __nosleep_restore --on-job-exit $job --inherit-variable schema --inherit-variable old_ac --inherit-variable old_bat
                  gsettings set $schema sleep-inactive-ac-type $old_ac
                  gsettings set $schema sleep-inactive-battery-type $old_bat
                  functions -e __nosleep_restore
              end

              fg $job
          end
        '';
      };
      programs.starship = {
        enableFishIntegration = true;
        enable = true;
        settings = {
          # Starship config
          format = "$all($satus)$line_break$character";
          hostname.disabled = true;
          status = {
            symbol = " ";
            success_symbol = "[➜ ](bold green)";
            map_symbol = true;
            sigint_symbol = "⚡";
            disabled = false;
            pipestatus = true;
          };
          container.disabled = true;
          username.disabled = true;
          git_branch.symbol = "⎇ ";
        };
      };
    };
}
