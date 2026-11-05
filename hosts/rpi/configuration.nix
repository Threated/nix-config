{ self, inputs, ... }:
{
  flake.nixosConfigurations.rpi = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      inputs.nixos-hardware.nixosModules.raspberry-pi-5
      self.nixosModules.rpi
    ];
  };

  flake.nixosModules.rpi = { modulesPath, ... }: {
    imports = [
      (modulesPath + "/profiles/minimal.nix")
      ./hardware-configuration.nix
    ];

    networking = {
      hostName = "rpi";
      useNetworkd = true;
      useDHCP = false;
      interfaces.eth0.useDHCP = true;
      firewall.enable = true;
    };

    time.timeZone = "Europe/Berlin";

    users.users.threated = {
      isNormalUser = true;
      uid = 1000;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keyFiles = [ ./threated.pub ];
    };
    # Allow unattended administration over SSH without a local password.
    security.sudo.wheelNeedsPassword = false;

    services.openssh = {
      enable = true;
      openFirewall = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
      };
    };

    services.journald.settings.Journal.SystemMaxUse = "250M";
    nix = {
      settings.experimental-features = [ "nix-command" "flakes" ];
      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 14d";
      };
    };

    system.stateVersion = "26.05";
  };
}
