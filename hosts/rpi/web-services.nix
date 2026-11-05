{ inputs, ... }:
{
  flake.nixosModules.rpi = { config, pkgs, ... }:
    let
      # Update public-facing applications independently of the Pi kernel pin.
      apps = import inputs.nixpkgs {
        system = pkgs.stdenv.hostPlatform.system;
      };
    in
    {
      imports = [ inputs.sops-nix.nixosModules.sops ];

      # Reach our own issuer without depending on router NAT loopback.
      networking.hosts."127.0.0.1" = [ "id.threated.dedyn.io" ];

      sops = {
        defaultSopsFile = ../../secrets/rpi.yaml;
        age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
        gnupg.sshKeyPaths = [ ];
        secrets.pocket-id-encryption-key.restartUnits = [ "pocket-id.service" ];
        secrets.headscale-oidc-client-secret.restartUnits = [ "headscale.service" ];
      };

      services.caddy = {
        enable = true;
        package = apps.caddy;
        openFirewall = true;
        virtualHosts = {
          # Keep request URLs out of access logs; service logs use capped journald.
          "id.threated.dedyn.io".logFormat = null;
          "http://headscale.threated.dedyn.io".logFormat = null;
          "headscale.threated.dedyn.io".logFormat = null;
          "id.threated.dedyn.io".extraConfig = ''
            # Initial administrator setup is only available from the LAN.
            @remoteSetup {
              path /setup /api/signup/setup
              not remote_ip 192.168.2.0/24 fd9a:a206:28e6:1::/64 2003:c1:f09:368e::/64 127.0.0.1 ::1
            }
            respond @remoteSetup 403
            reverse_proxy 127.0.0.1:1411
          '';
          "http://headscale.threated.dedyn.io".extraConfig = ''
            handle /generate_204 {
              respond 204
            }
            handle {
              redir https://{host}{uri} permanent
            }
          '';
          "headscale.threated.dedyn.io".extraConfig = ''
            reverse_proxy 127.0.0.1:8080 {
              header_up True-Client-IP {remote_host}
              header_up X-Real-IP {remote_host}
            }
          '';
        };
      };

      services.pocket-id = {
        enable = true;
        package = apps.pocket-id;
        credentials.ENCRYPTION_KEY = config.sops.secrets.pocket-id-encryption-key.path;
        settings = {
          APP_URL = "https://id.threated.dedyn.io";
          HOST = "127.0.0.1";
          PORT = 1411;
          ACTORS_HOST = "127.0.0.1";
          TRUST_PROXY = true;
          ANALYTICS_DISABLED = true;
          VERSION_CHECK_DISABLED = true;
          ALLOW_INSECURE_CALLBACK_URLS = false;
          UI_CONFIG_DISABLED = true;
          ALLOW_USER_SIGNUPS = "disabled";
          # Accounts are created by the administrator; no SMTP is configured.
          EMAILS_VERIFIED = true;
        };
      };

      services.headscale = {
        enable = true;
        package = apps.headscale;
        address = "127.0.0.1";
        port = 8080;
        settings = {
          server_url = "https://headscale.threated.dedyn.io";
          metrics_listen_addr = "127.0.0.1:9090";
          grpc_listen_addr = "127.0.0.1:50443";
          trusted_proxies = [ "127.0.0.1/32" ];
          # Keep clients' existing resolvers; MagicDNS only names VPN peers.
          dns = {
            base_domain = "tail.threated.dedyn.io";
            override_local_dns = false;
          };
          oidc = {
            issuer = "https://id.threated.dedyn.io";
            client_id = "headscale";
            client_secret_path = "\${CREDENTIALS_DIRECTORY}/oidc-client-secret";
            pkce = { enabled = true; method = "S256"; };
            only_start_if_oidc_is_available = true;
          };
        };
      };
      systemd.services.headscale = {
        wants = [ "pocket-id.service" "caddy.service" ];
        after = [ "pocket-id.service" "caddy.service" ];
        serviceConfig.LoadCredential = [
          "oidc-client-secret:${config.sops.secrets.headscale-oidc-client-secret.path}"
        ];
      };
    };
}
