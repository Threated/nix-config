{ inputs, ... }:
{
  # This is your module that imports and configures home-manager
  flake.nixosModules.hm =
    { ... }:
    {
      imports = [
        inputs.home-manager.nixosModules.default # import official home-manager NixOS module
      ];

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
      };
    };
}
