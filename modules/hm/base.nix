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
      imports = [ ];
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
        inputs.codex-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
        nil
        nixd
        gdb
        bun
        dolphin-emu
        self.packages.${pkgs.stdenv.hostPlatform.system}.jj
        self.packages.${pkgs.stdenv.hostPlatform.system}.ghostty
        self.packages.${pkgs.stdenv.hostPlatform.system}.fish
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
    };
}
