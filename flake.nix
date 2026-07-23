{
  description = "Nix configurations";

  nixConfig = {
    extra-substituters = [ "https://noctalia.cachix.org" ];
    extra-trusted-public-keys =
      [ "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4=" ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
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

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];

      imports = [
        inputs.home-manager.flakeModules.home-manager
        ./hosts/laptop/configuration.nix
        ./modules/hm/base.nix
        ./modules/nix/hm.nix
        ./modules/wrapped/jj.nix
        ./modules/wrapped/niri.nix
        ./modules/wrapped/noctalia.nix
        ./modules/wrapped/wezterm.nix
        ./modules/wrapped/fish.nix
      ];
    };
}
