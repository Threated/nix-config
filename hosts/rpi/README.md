# Raspberry Pi

Native systemd services; no containers:

| Name | Listener | Public URL |
| --- | --- | --- |
| Caddy | TCP 80/443, UDP 443 | Automatic HTTPS and reverse proxy |
| Pocket ID | 127.0.0.1:1411 | https://id.threated.dedyn.io |
| Headscale | 127.0.0.1:8080 | https://headscale.threated.dedyn.io |
| Pi-hole | LAN TCP/UDP 53 | DNS blocking only |
| Hue Music (optional private input) | LAN TCP 8098 | http://rpi:8098 |

Headscale's metrics and gRPC listeners are loopback-only. It uses the public
Tailscale DERP map for fallback relays. MagicDNS names peers under
`tail.threated.dedyn.io`; it does not override clients' existing DNS resolvers.

Run `just` from the repository to list deployment and secret-management commands.
The optional, ignored `.env` file can set `ASSISTANT_PATH` and `HUE_MUSIC_PATH`
to private checkouts. `just deploy-rpi` includes whichever paths are configured;
two optional positional arguments override those paths. `just deploy-rpi "" ""`
deploys the public base alone. `.env.example` lists the variables.

CI deploys pushes to `main` over Tailscale SSH, using the exact public commit
and private sources from the Pi's bare repositories in `~/git`. Run
`just push-rpi-inputs` after committing private changes to update those remotes
before the next deployment. The workflow also supports manual runs.
CI requires the `HEADSCALE_AUTHKEY` secret for a reusable, ephemeral Headscale
key tagged `tag:ci`; renew it before it expires. Deployment requires both private
repositories and stops if either is missing.
The CI tag can connect only to TCP port 22 on the Pi. Deployment uses the
`threated` account's existing sudo access on the Pi.
