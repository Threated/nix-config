{ ... }:
{
  flake.nixosModules.nix-settings = { lib, ... }: {
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    # Keep this list authoritative, including over the Raspberry Pi defaults.
    nix.settings.substituters = lib.mkForce [
      "https://cache.nixos.org/"
      "https://noctalia.cachix.org"
      "https://nixos-raspberrypi.cachix.org"
    ];
    nix.settings.trusted-public-keys = lib.mkForce [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };
}
