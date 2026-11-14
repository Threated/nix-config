{
  description = "Nix configurations";

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
    import-tree.url = "github:denful/import-tree";
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
        (inputs.import-tree ./modules)
        # Hardware files are NixOS modules, imported by their host configuration.
        ((inputs.import-tree.filter (path: builtins.baseNameOf path != "hardware-configuration.nix")) ./hosts)
      ];
    };
}
