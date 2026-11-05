{ ... }:
{
  flake.nixosModules.rpi = {
    # Temporary CVE-2026-98432 mitigation for the unpatched vendor kernel.
    # Filter before Tailscale's INPUT accept rules and conntrack processing.
    # This leaves TCP options (MSS, timestamps, window scaling) untouched.
    # Remove after booting a kernel containing the upstream RCU fixes.
    # https://docs.aws.amazon.com/en_en/lightsail/latest/userguide/address-cve-2026-98432.html
    networking.firewall = {
      extraCommands = ''
        iptables -t raw -C PREROUTING -p tcp -m u32 --u32 '0>>24&0x0f=6:15' -j DROP 2>/dev/null || \
          iptables -t raw -I PREROUTING 1 -p tcp -m u32 --u32 '0>>24&0x0f=6:15' -j DROP
      '';
      extraStopCommands = ''
        iptables -t raw -D PREROUTING -p tcp -m u32 --u32 '0>>24&0x0f=6:15' -j DROP 2>/dev/null || true
      '';
    };
  };
}
