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
git init --bare --quiet "$work/public.git"
git --git-dir="$work/public.git" fetch --quiet --depth=1 --no-tags \
  https://github.com/Threated/nix-config.git refs/heads/main
approved_revision=$(git --git-dir="$work/public.git" rev-parse --verify 'FETCH_HEAD^{commit}')
if [[ "$revision" != "$approved_revision" ]]; then
  echo 'Refusing deployment: requested revision is not the current main commit' >&2
  exit 1
fi

for input in assistant hue-music; do
  repo="/home/threated/git/$input.git"
  private_revision=$(git -c safe.directory="$repo" --git-dir="$repo" rev-parse --verify refs/heads/main)
  echo "$input: $private_revision"
  mkdir "$work/$input"
  git -c safe.directory="$repo" --git-dir="$repo" archive "$private_revision" |
    tar -x -C "$work/$input"
  test -f "$work/$input/flake.nix"
done

nixos-rebuild switch --flake "github:Threated/nix-config/$revision#rpi" \
  --override-input assistant "path:$work/assistant" \
  --override-input hue-music "path:$work/hue-music" \
  --no-write-lock-file --no-reexec
