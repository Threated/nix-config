{
  description = "Public no-op placeholder for optional private Hue Music";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { ... }: {
    nixosModules.default = { };
  };
}
