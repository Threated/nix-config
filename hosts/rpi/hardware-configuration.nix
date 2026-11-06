{ pkgs, ... }:
{
  nixpkgs.hostPlatform = "aarch64-linux";

  hardware.raspberry-pi.config.all.dt-overlays = {
    gpio-ir = {
      enable = true;
      params.gpio_pin = { enable = true; value = 16; };
    };
    gpio-ir-tx = {
      enable = true;
      params.gpio_pin = { enable = true; value = 20; };
    };
  };
  services.udev.extraRules = ''
    SUBSYSTEM=="lirc", KERNEL=="lirc[0-9]*", DRIVERS=="gpio-ir-tx", SYMLINK+="lirc-transmitter", GROUP="video", MODE="0660"
    SUBSYSTEM=="lirc", KERNEL=="lirc[0-9]*", DRIVERS=="gpio_ir_recv", SYMLINK+="lirc-receiver", GROUP="video", MODE="0660"
  '';
  environment.systemPackages = [ (pkgs.v4l-utils.override { withGUI = false; withBPF = false; }) ];

  # Reuse the existing microSD partitions during the migration.
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/ce208fd3-38a8-424a-87a2-cd44114eb820";
    fsType = "ext4";
  };
  fileSystems."/boot/firmware" = {
    device = "/dev/disk/by-uuid/4EF5-6F55";
    fsType = "vfat";
    options = [ "umask=0077" ];
  };

  # Boot the matched vendor kernel directly through the Pi firmware.
  boot.loader.raspberry-pi = {
    bootloader = "kernel";
    # Leave room for atomic boot-file updates on the 510 MiB firmware partition.
    configurationLimit = 3;
  };
}
