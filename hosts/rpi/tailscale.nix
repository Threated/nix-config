{ inputs, ... }:
{
  flake.nixosModules.rpi = { pkgs, ... }: {
    services.tailscale = {
      enable = true;
      package = inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system}.tailscale;
      openFirewall = true;
      useRoutingFeatures = "server";
      # Enrollment is one-time; tailscaled keeps its identity in /var/lib/tailscale.
      extraUpFlags = [
        "--login-server=https://headscale.threated.dedyn.io"
        "--ssh"
        "--advertise-exit-node"
        "--accept-dns=false"
      ];
      extraSetFlags = [ "--ssh" "--advertise-exit-node" "--accept-dns=false" ];
    };

    boot.kernelModules = [ "nft_chain_nat" ];
    networking.firewall.trustedInterfaces = [ "tailscale0" ];
    # Continue learning the ISP prefix/default route when IPv6 forwarding is on.
    systemd.network.networks."40-eth0".networkConfig.IPv6AcceptRA = true;
    systemd.services.tailscaled.serviceConfig.Environment = [
      "TS_DEBUG_FIREWALL_MODE=nftables"
    ];
  };
}
