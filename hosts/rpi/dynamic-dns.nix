{ ... }:
{
  flake.nixosModules.rpi = { config, ... }: {
    sops.secrets.desec-token.restartUnits = [ "ddclient.service" ];

    # Publish this host's IPv6 address rather than the router's address.
    # The two service CNAMEs inherit these A/AAAA records.
    services.ddclient = {
      enable = true;
      protocol = "dyndns2";
      server = "update.dedyn.io";
      username = "threated.dedyn.io";
      domains = [ "threated.dedyn.io" ];
      passwordFile = config.sops.secrets.desec-token.path;
      usev4 = "webv4, webv4=https://checkipv4.dedyn.io/";
      # ddclient filters out temporary/deprecated addresses and ULAs.
      usev6 = "ifv6, ifv6=eth0";
      interval = "5min";
      ssl = true;
      quiet = true;
    };
    systemd.services.ddclient = {
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
    };
  };
}
