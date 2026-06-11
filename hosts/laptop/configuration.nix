{ self, inputs, ... }:
{

  # This is your system configuration entry-point
  flake.nixosConfigurations.laptop = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules.laptop
      self.nixosModules.hm
    ];
  };

  # This is your configuration.nix, a place where you configure your system
  # You can place it in a separate file.
  flake.nixosModules.laptop =
    { pkgs, config, ... }:
    {
      home-manager.users.threated = self.homeModules.base;

      imports = [
        # Include the results of the hardware scan.
        ./hardware-configuration.nix
      ];

      # Bootloader.
      boot.loader.systemd-boot.enable = true;
      boot.loader.systemd-boot.configurationLimit = 5;
      boot.loader.efi.canTouchEfiVariables = true;

      networking.hostName = "nixos"; # Define your hostname.
      # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

      # Enable networking
      networking.networkmanager.enable = true;

      virtualisation.docker.enable = true;
      virtualisation.docker.liveRestore = false;

      # Set your time zone.
      time.timeZone = "Europe/Berlin";

      # Select internationalisation properties.
      i18n.defaultLocale = "en_US.UTF-8";

      i18n.extraLocaleSettings = {
        LC_ADDRESS = "de_DE.UTF-8";
        LC_IDENTIFICATION = "de_DE.UTF-8";
        LC_MEASUREMENT = "de_DE.UTF-8";
        LC_MONETARY = "de_DE.UTF-8";
        LC_NAME = "de_DE.UTF-8";
        LC_NUMERIC = "de_DE.UTF-8";
        LC_PAPER = "de_DE.UTF-8";
        LC_TELEPHONE = "de_DE.UTF-8";
        LC_TIME = "de_DE.UTF-8";
      };

      # Enable the X11 windowing system.
      services.xserver.enable = true;

      # Enable the GNOME Desktop Environment.
      services.displayManager.gdm.enable = true;
      services.desktopManager.gnome.enable = true;
      services.hardware.bolt.enable = true;
      services.xserver.excludePackages = [
        pkgs.xterm
        pkgs.gnome-console
      ];

      # Configure keymap in X11
      services.xserver.xkb = {
        layout = "de";
        variant = "";
        options = "ctrl:nocaps";
      };
      #programs.hyprland = {
      #enable = true;
      #xwayland.enable = true;
      #};
      #xdg.portal.enable = true;
      #xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

      environment.sessionVariables = {
        # If your cursor becomes invisible
        # WLR_NO_HARDWARE_CURSORS = "1";
        # Hint electron apps to use wayland
        NIXOS_OZONE_WL = "1";
        PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
      };

      console.useXkbConfig = true;
      # Configure console keymap
      # console.keyMap = "de";
      fonts.packages = [
        #(pkgs.nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
        (pkgs.nerd-fonts.jetbrains-mono)
      ];
      fonts.fontconfig.defaultFonts = {
        serif = [ "JetBrainsMono" ];
        sansSerif = [ "JetBrainsMono" ];
        monospace = [ "JetBrainsMono" ];
      };

      # Enable CUPS to print documents.
      services.printing.enable = true;

      # Enable sound with pipewire.
      hardware.bluetooth.enable = true;
      services.pulseaudio.enable = false;
      security.rtkit.enable = true;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        # If you want to use JACK applications, uncomment this
        #jack.enable = true;

        # use the example session manager (no others are packaged yet so this is enabled by default,
        # no need to redefine it in your config for now)
        #media-session.enable = true;
      };

      # Enable touchpad support (enabled default in most desktopManager).
      # services.xserver.libinput.enable = true;

      # Define a user account. Don't forget to set a password with ‘passwd’.
      users.extraGroups.docker.members = [ "threated" ];
      users.users.threated = {
        isNormalUser = true;
        description = "threated";
        extraGroups = [
          "networkmanager"
          "wheel"
        ];
        shell = self.packages.${pkgs.stdenv.hostPlatform.system}.fish;
      };
      environment.shells = [ self.packages.${pkgs.stdenv.hostPlatform.system}.fish ];

      # Allow unfree packages
      nixpkgs.config.allowUnfree = true;

      # List packages installed in system profile. To search, run:
      # $ nix search wget
      environment.systemPackages = with pkgs; [
        vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
        curl
        ripgrep
        bat
        git
        gh
        wl-clipboard
        # hyprland stuff
        # kitty
        #waybar
        #libnotify
        #swww
        #rofi-wayland
      ];

      programs.steam.enable = true;
      # Some programs need SUID wrappers, can be configured further or are
      # started in user sessions.
      # programs.mtr.enable = true;
      # programs.gnupg.agent = {
      #   enable = true;
      #   enableSSHSupport = true;
      # };
      nix.settings.experimental-features = [
        "nix-command"
        "flakes"
      ];

      # List services that you want to enable:

      # Enable the OpenSSH daemon.
      # services.openssh.enable = true;
      # Tailscale setup
      # 1. Enable the service and the firewall
      services.tailscale.enable = true;
      services.tailscale.package = pkgs.tailscale;
      services.tailscale.extraUpFlags = [ "--ssh" ];

      networking.nftables.enable = true;
      networking.firewall = {
        enable = true;
        # Always allow traffic from your Tailscale network
        trustedInterfaces = [ "tailscale0" ];
        # Allow the Tailscale UDP port through the firewall
        allowedUDPPorts = [ config.services.tailscale.port ];
      };

      # 2. Force tailscaled to use nftables (Critical for clean nftables-only systems)
      # This avoids the "iptables-compat" translation layer issues.
      systemd.services.tailscaled.serviceConfig.Environment = [
        "TS_DEBUG_FIREWALL_MODE=nftables"
      ];

      # 3. Optimization: Prevent systemd from waiting for network online
      # (Optional but recommended for faster boot with VPNs)
      systemd.network.wait-online.enable = false;
      boot.initrd.systemd.network.wait-online.enable = false;
      # Tailscale setup end

      # Open ports in the firewall.
      # networking.firewall.allowedTCPPorts = [ ... ];
      # networking.firewall.allowedUDPPorts = [ ... ];
      # Or disable the firewall altogether.
      # networking.firewall.enable = false;

      # This value determines the NixOS release from which the default
      # settings for stateful data, like file locations and database versions
      # on your system were taken. It‘s perfectly fine and recommended to leave
      # this value at the release version of the first install of this system.
      # Before changing this value read the documentation for this option
      # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
      system.stateVersion = "23.11"; # Did you read the comment?

    };

}
