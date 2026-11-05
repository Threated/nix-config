# Raspberry Pi

Native systemd services; no containers:

| Name | Listener | Public URL |
| --- | --- | --- |
| Caddy | TCP 80/443, UDP 443 | Automatic HTTPS and reverse proxy |
| Pocket ID | 127.0.0.1:1411 | https://id.threated.dedyn.io |
| Headscale | 127.0.0.1:8080 | https://headscale.threated.dedyn.io |
| Pi-hole | LAN TCP/UDP 53 | DNS blocking only |

Headscale's metrics and gRPC listeners are loopback-only. It uses the public
Tailscale DERP map for fallback relays. MagicDNS names peers under
`tail.threated.dedyn.io`; it does not override clients' existing DNS resolvers.

## Deploy

From this laptop:

```sh
NIX_SSHOPTS='-o BatchMode=yes -o HostKeyAlias=raspberrypi -o IdentitiesOnly=yes -i /home/threated/.ssh/id_ed25519' \
  nixos-rebuild switch --flake .#rpi \
  --build-host threated@192.168.2.221 --target-host threated@192.168.2.221 \
  --elevate sudo --no-reexec
```

The Pi kernel uses the vendor input's own nixpkgs pin to match its binary cache.
Public-facing application packages come from the main nixpkgs input.

## Secrets

`secrets/rpi.yaml` is encrypted with SOPS/age for two recipients, declared in
`.sops.yaml`: this laptop's Ed25519 SSH identity and the Pi's Ed25519 SSH host
identity. No private keys or plaintext secrets belong in this repository.

At activation, sops-nix decrypts secrets into `/run/secrets` with root-only
permissions. systemd `LoadCredential` gives each service only its own secret.
Pocket ID receives its encryption key through the NixOS module's credential
support; Headscale reads its OIDC secret from its systemd credential directory.

To edit secrets using the laptop's SSH key:

```sh
nix shell nixpkgs#sops nixpkgs#ssh-to-age -c bash
export SOPS_AGE_KEY="$(ssh-to-age -private-key -i ~/.ssh/id_ed25519)"
sops secrets/rpi.yaml
unset SOPS_AGE_KEY
```

Back up the laptop's private Ed25519 key separately. Restoring the encrypted
file and Pocket ID database without a matching decryption key is insufficient.
Keep the Pocket ID encryption key with its database backups; changing or losing
it prevents decryption of existing data. If the Pi host key changes, use the
laptop recipient to re-encrypt with the new Pi recipient (`sops updatekeys`).

## Initial setup and OIDC

Open https://id.threated.dedyn.io/setup from the LAN and create your initial
administrator and passkey. Caddy restricts both `/setup` and `/api/signup/setup`
to LAN clients. Pocket ID closes initial setup once an administrator exists.
The initial setup allowlist includes the current ISP IPv6 LAN prefix; update
that allowlist if the prefix changes before initial setup is completed.

The OIDC client is named `Headscale`, ID `headscale`, with PKCE/S256 and callback
`https://headscale.threated.dedyn.io/oidc/callback`. Its secret is in SOPS.
Pocket ID users can authenticate to this client; keep public signup disabled
and manage access through Pocket ID users and client groups as needed.
Application settings come from Nix. Public signup is disabled, and email
addresses on administrator-managed accounts are treated as verified without
an SMTP verification flow.

## Router and DNS

Forward WAN TCP 80 and 443 to `192.168.2.221`. Caddy obtains and renews public
certificates automatically. The A records should resolve to the router's public
IPv4 address. AAAA records must resolve to the Pi's current global IPv6 address,
and its router IPv6 firewall must allow TCP 80 and 443. Publishing the router's
own IPv6 address does not implement IPv4-style port forwarding.

`ddclient` checks the Pi's public IPv4 and IPv6 every five minutes and updates
the apex `threated.dedyn.io` records through deSEC over HTTPS. The service
CNAMEs inherit these addresses. Disable the router's dynamic DNS updater to
avoid competing updates. The scoped token is encrypted as `desec-token` in
SOPS; the ddclient module writes its runtime configuration with mode 600.

Do not forward Pi-hole DNS or the backend service ports to the internet.

## Kernel security

On 2026-11-05, the running vendor kernel was `6.18.34`, source revision
`c8c7494100e99ee05b11aaa4f0588a223a63d1af`. Source inspection confirmed both
unpatched `kfree()` calls described by CVE-2026-98432, in `inet_sock_destruct()`
and `tcp_v4_reqsk_destructor()`. The configured kernel patches do not fix them.
This assessment did not run an exploit against the server.

`security.nix` persists an INPUT filter dropping IPv4 TCP packets with IPv4
options, ahead of the normal stateful firewall. Standard TCP options and IPv6
are unaffected. This is a temporary exposure reduction, not a kernel fix.
Replace the kernel with a tested vendor build containing the RCU fixes
(upstream 6.18.56 or a backport), reboot, verify the running kernel, and then
remove this filter.

References:

- https://github.com/CVEProject/cvelistV5/blob/main/cves/2026/98xxx/CVE-2026-98432.json
- https://access.redhat.com/security/vulnerabilities/RHSB-2026-016
- https://docs.aws.amazon.com/en_en/lightsail/latest/userguide/address-cve-2026-98432.html
