{
  description = "Nix configurations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];

      imports = [
        inputs.home-manager.flakeModules.home-manager
        ./hosts/laptop/configuration.nix
        ./modules/hm/base.nix
        ./modules/hm/jj.nix
        ./modules/nix/hm.nix
      ];
    };
}
