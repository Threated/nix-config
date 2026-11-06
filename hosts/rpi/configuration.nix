{ self, inputs, ... }:
{
  flake.nixosConfigurations.rpi = inputs.nixos-raspberrypi.lib.nixosSystem {
    modules = [
      inputs.nixos-raspberrypi.nixosModules.raspberry-pi-5.base
      self.nixosModules.rpi
    ];
  };

  flake.nixosModules.rpi = { modulesPath, ... }: {
    imports = [
      (modulesPath + "/profiles/minimal.nix")
      ./hardware-configuration.nix
        inputs.assistant.nixosModules.default
    ];

    networking = {
      hostName = "rpi";
      useNetworkd = true;
      # Keep the interface name used by the DHCP configuration below.
      usePredictableInterfaceNames = false;
      useDHCP = false;
      interfaces.eth0.useDHCP = true;
      firewall.enable = true;
    };
    # The Speedport grants the existing IPv4 lease when identified by MAC.
    systemd.network.networks."40-eth0".dhcpV4Config.ClientIdentifier = "mac";

    # The vendor rule refers to Raspberry Pi OS's sudo group; NixOS uses wheel.
    environment.etc."tmpfiles.d/sys-kernel-debug.conf".text =
      "d! /sys/kernel/debug 0750 root wheel -\n";

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

    services.journald = {
      storage = "persistent";
      extraConfig = "SystemMaxUse=250M";
    };
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
