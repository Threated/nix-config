{
  description = "Nix configurations";

  nixConfig = {
    extra-substituters = [
      "https://noctalia.cachix.org"
      "https://nixos-raspberrypi.cachix.org"
    ];
    extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # Keep its own nixpkgs pin so the Pi kernel and firmware match its cache.
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    assistant = {
      url = "path:./inputs/assistant";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hue-music = {
      url = "path:./inputs/hue-music";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
    wrapper-modules.url = "github:BirdeeHub/nix-wrapper-modules";
    wrapper-modules.inputs.nixpkgs.follows = "nixpkgs";

    # Keep Noctalia's own nixpkgs input: changing it would invalidate the
    # derivations published by the project's binary cache.
    noctalia.url = "github:noctalia-dev/noctalia/cachix";

    noctalia-greeter = {
      url = "github:noctalia-dev/noctalia-greeter";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    codex-cli-nix.url = "github:sadjow/codex-cli-nix";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];

      perSystem =
        { system, ... }:
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
        };

      imports = [
        ./modules/theme.nix
        ./hosts/laptop/configuration.nix
        ./hosts/rpi/configuration.nix
        ./hosts/rpi/pihole.nix
        ./hosts/rpi/web-services.nix
        ./hosts/rpi/security.nix
        ./hosts/rpi/dynamic-dns.nix
        ./hosts/rpi/tailscale.nix
        ./modules/wrapped/jj.nix
        ./modules/wrapped/niri.nix
        ./modules/wrapped/noctalia.nix
        ./modules/wrapped/wezterm.nix
        ./modules/wrapped/ghostty.nix
        ./modules/wrapped/fish.nix
        ./modules/wrapped/chrome.nix
        ./modules/rustup.nix
      ];
    };
}
