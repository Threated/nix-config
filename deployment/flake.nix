{
  description = "Pi deployment with private sources from its local Git repositories";

  inputs = {
    nix-config.url = "path:..";
    assistant = {
      url = "git+file:///home/threated/git/assistant.git?ref=main";
      inputs.nixpkgs.follows = "nix-config/nixpkgs";
    };
    hue-music = {
      url = "git+file:///home/threated/git/hue-music.git?ref=main";
      inputs.nixpkgs.follows = "nix-config/nixpkgs";
    };
  };

  outputs = { nix-config, assistant, hue-music, ... }: {
    nixosConfigurations.rpi = nix-config.nixosConfigurations.rpi.extendModules {
      modules = [
        assistant.nixosModules.default
        hue-music.nixosModules.default
      ];
    };
  };
}
