{ inputs, ... }:
{
  flake.nixosModules.rpi = { lib, pkgs, ... }:
    let
      # Keep Pi-hole current independently of the vendor kernel's nixpkgs pin.
      piholePkgs = import inputs.nixpkgs {
        system = pkgs.stdenv.hostPlatform.system;
      };
    in
    {
      # Free port 53 for Pi-hole while keeping the host's upstream DNS usable.
      services.resolved.settings.Resolve.DNSStubListener = false;
      environment.etc."resolv.conf".source =
        lib.mkForce "/run/systemd/resolve/resolv.conf";

      services.pihole-ftl = {
        enable = true;
        package = piholePkgs.pihole-ftl;
        piholePackage = piholePkgs.pihole;
        openFirewallDNS = true;
        settings = {
          dns = {
            upstreams = [ "8.8.8.8" "8.8.4.4" ];
            listeningMode = "LOCAL";
            queryLogging = false;
          };
          dhcp.active = false;
          database.maxDBdays = 0;
          webserver.port = "";
          # The host already runs systemd-timesyncd.
          ntp = {
            ipv4.active = false;
            ipv6.active = false;
            sync.active = false;
          };
        };
      };

      systemd.services.pihole-ftl.after = [ "systemd-resolved.service" ];

      systemd.services.pihole-gravity = {
        description = "Refresh Pi-hole blocklists";
        requires = [ "pihole-ftl.service" ];
        wants = [ "network-online.target" ];
        after = [ "pihole-ftl.service" "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          User = "pihole";
          Group = "pihole";
          ExecStart = "${piholePkgs.pihole}/bin/pihole -g";
          ExecStartPost =
            "+${pkgs.systemd}/bin/systemctl kill --signal=RTMIN pihole-ftl.service";
        };
      };
      systemd.timers.pihole-gravity = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "Sun *-*-* 04:30:00";
          RandomizedDelaySec = "1h";
          Persistent = true;
        };
      };
    };
}
