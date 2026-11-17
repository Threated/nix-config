set -euo pipefail

revision=${1:?Expected a nix-config commit SHA}
if [[ ! "$revision" =~ ^[0-9a-f]{40}$ ]]; then
  echo 'Expected a full commit SHA' >&2
  exit 1
fi

exec 9>/var/lock/rpi-deploy.lock
flock 9

work=$(mktemp -d /var/tmp/rpi-deploy.XXXXXXXX)
trap 'rm -rf "$work"' EXIT

# A CI credential may request deployment, but cannot select unreviewed code or
# roll back to an older main commit. Check GitHub again on the Pi, as root.
git clone --quiet --depth=1 --branch=main \
  https://github.com/Threated/nix-config.git "$work/config"
approved_revision=$(git -C "$work/config" rev-parse --verify 'HEAD^{commit}')
if [[ "$revision" != "$approved_revision" ]]; then
  echo 'Refusing deployment: requested revision is not the current main commit' >&2
  exit 1
fi

nixos-rebuild switch --flake "$work/config/deployment#rpi" \
  --refresh --no-write-lock-file --no-reexec
