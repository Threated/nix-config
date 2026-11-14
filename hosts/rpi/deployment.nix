{ ... }:
{
  flake.nixosModules.rpi = { pkgs, ... }:
    let
      deploy = pkgs.writeShellApplication {
        name = "rpi-deploy";
        runtimeInputs = with pkgs; [ coreutils git gnutar nix nixos-rebuild util-linux ];
        text = builtins.readFile ../../scripts/deploy-rpi.sh;
      };
    in
    {
      environment.systemPackages = [ pkgs.git deploy ];
      systemd.tmpfiles.rules = [ "d /home/threated/git 0700 threated users -" ];
    };
}
