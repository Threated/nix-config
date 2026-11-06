{
  description = "Public no-op placeholder for the optional private assistant";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { ... }: {
    nixosModules.default = { };
  };
}
