# Raspberry Pi

Native systemd services; no containers:

| Name | Listener | Public URL |
| --- | --- | --- |
| Caddy | TCP 80/443, UDP 443 | Automatic HTTPS and reverse proxy |
| Pocket ID | 127.0.0.1:1411 | https://id.threated.dedyn.io |
| Headscale | 127.0.0.1:8080 | https://headscale.threated.dedyn.io |
| Pi-hole | LAN TCP/UDP 53 | DNS blocking only |
| Hue Music (private deployment flake) | LAN TCP 8098 | http://rpi:8098 |

Headscale's metrics and gRPC listeners are loopback-only. It uses the public
Tailscale DERP map for fallback relays. MagicDNS names peers under
`tail.threated.dedyn.io`; it does not override clients' existing DNS resolvers.

The root flake is public: its packages and base Pi configuration do not depend
on private repositories. Commands such as `nix run github:Threated/nix-config#jj`
work without access to the Pi. The separate `deployment/flake.nix` extends the
base Pi configuration with Assistant and Hue Music, fetched directly from the
Pi's bare Git repositories in `/home/threated/git`. There are no placeholder
inputs or input overrides. Evaluate this flake from a Git checkout so its
relative `path:..` input can access the public flake in the same repository.

Run `just` to list deployment and secret-management commands. `just deploy-rpi`
deploys the current committed public revision, which must already be the tip of
GitHub's `main`; uncommitted local edits are not deployed. The ignored `.env`
can set `ASSISTANT_PATH` and `HUE_MUSIC_PATH` for `just push-rpi-inputs` only.

CI deploys pushes to `main` over Tailscale SSH, using the exact public commit
and private sources from the Pi's bare repositories in `~/git`. Run
`just push-rpi-inputs` after committing private changes to update those remotes
before the next deployment. The workflow also supports manual runs.
CI requires the `HEADSCALE_AUTHKEY` secret for a reusable, ephemeral Headscale
key tagged `tag:ci`; renew it before it expires. Deployment requires both private
repositories and stops if either is missing. The deployment flake resolves their
`main` branches fresh on every run (`--refresh`); its generated lock is not
committed. The root lock continues to pin all public dependencies.
The CI tag can connect only to TCP port 22 on the Pi and log in only as `rpi-ci`.
This is an ordinary unprivileged account, with sudo restricted to starting,
reading logs from, and stopping `nix-config-deploy@<SHA>.service` units. The Pi
checks that the SHA is the current public `main` commit before rebuilding.
Stale runs fail if `main` has advanced; the latest run deploys the new tip.

`Threated@` has unrestricted network and Tailscale SSH access. Other personal
devices have unrestricted network access to all peers and can use the Pi's
approved exit routes, but have no Tailscale SSH authorization. Ordinary OpenSSH
services still enforce their own key authentication. CI has a normal user shell,
including normal user networking; it has no general administrator access.

When migrating from the old input-override layout, first install the new system
from this repository's `deployment` flake on the Pi. Do this before pushing the
root-flake change, because the old running deployment helper does not know about
the new deployment flake and would otherwise deploy only the public base.
