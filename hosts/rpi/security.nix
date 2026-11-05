{ ... }:
{
  flake.nixosModules.rpi = {
    # Temporary CVE-2026-98432 mitigation for the unpatched vendor kernel.
    # Drop IPv4 TCP packets carrying IP options before conntrack accepts them.
    # This leaves TCP options (MSS, timestamps, window scaling) untouched.
    # Remove after booting a kernel containing the upstream RCU fixes.
    # https://docs.aws.amazon.com/en_en/lightsail/latest/userguide/address-cve-2026-98432.html
    networking.firewall = {
      extraCommands = ''
        iptables -C INPUT -p tcp -m u32 --u32 '0>>24&0x0f=6:15' -j DROP 2>/dev/null || \
          iptables -I INPUT 1 -p tcp -m u32 --u32 '0>>24&0x0f=6:15' -j DROP
      '';
      extraStopCommands = ''
        iptables -D INPUT -p tcp -m u32 --u32 '0>>24&0x0f=6:15' -j DROP 2>/dev/null || true
      '';
    };
  };
}
