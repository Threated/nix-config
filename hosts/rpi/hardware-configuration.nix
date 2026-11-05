{ ... }:
{
  nixpkgs.hostPlatform = "aarch64-linux";

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
