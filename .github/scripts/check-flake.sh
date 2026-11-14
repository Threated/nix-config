#!/usr/bin/env bash
set -euo pipefail

nix flake check --all-systems --no-build --no-update-lock-file

for host in laptop rpi; do
  nix eval --raw --no-update-lock-file \
    ".#nixosConfigurations.${host}.config.system.build.toplevel.drvPath"
  printf '\n'
done
