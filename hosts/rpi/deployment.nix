{ ... }:
{
  flake.nixosModules.rpi = { pkgs, ... }:
    let
      deploy = pkgs.writeShellApplication {
        name = "rpi-deploy";
        runtimeInputs = with pkgs; [ coreutils git nix nixos-rebuild util-linux ];
        text = builtins.readFile ../../scripts/deploy-rpi.sh;
      };
    in
    {
      environment.systemPackages = [ pkgs.git deploy ];
      systemd.tmpfiles.rules = [ "d /home/threated/git 0700 threated users -" ];

      users.groups.rpi-ci = { };
      users.users.rpi-ci = {
        isSystemUser = true;
        group = "rpi-ci";
        home = "/var/empty";
        shell = pkgs.bashInteractive;
      };

      systemd.services."nix-config-deploy@" = {
        description = "Deploy nix-config revision %i";
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          TimeoutStartSec = "55min";
          ExecStart = "${deploy}/bin/rpi-deploy %i";
        };
      };

      # Anchored argument regexes: no arbitrary units, options, or commands.
      security.sudo.extraRules = [{
        users = [ "rpi-ci" ];
        runAs = "root";
        commands = [
          {
            command = ''/run/current-system/sw/bin/systemctl ^(restart --no-block|stop) nix-config-deploy@[0-9a-f]{40}\.service$'';
            options = [ "NOPASSWD" "NOSETENV" ];
          }
          {
            command = ''/run/current-system/sw/bin/journalctl ^--unit=nix-config-deploy@[0-9a-f]{40}\.service --no-pager$'';
            options = [ "NOPASSWD" "NOSETENV" ];
          }
        ];
      }];
    };
}
