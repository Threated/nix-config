set positional-arguments
set dotenv-load

# List available commands.
default:
    @just --list

# Build on the Pi and deploy its NixOS configuration.
deploy-rpi assistant=env("ASSISTANT_PATH", ""):
    #!/usr/bin/env bash
    set -euo pipefail
    override=()
    if [[ -n "$1" ]]; then
        override=(--override-input assistant "$(realpath "$1")" --no-write-lock-file)
    fi
    export NIX_SSHOPTS='-o BatchMode=yes'
    nixos-rebuild switch --flake .#rpi --build-host threated@rpi --target-host threated@rpi --elevate sudo --no-reexec "${override[@]}"

# Edit encrypted secrets using your Ed25519 SSH identity.
secrets file="secrets/rpi.yaml": (_sops "edit" file)

# Apply recipient changes from .sops.yaml to an encrypted secrets file.
secrets-updatekeys file="secrets/rpi.yaml": (_sops "updatekeys" file)

[private]
_sops action file:
    #!/usr/bin/env bash
    set -euo pipefail
    nix shell --inputs-from . nixpkgs#sops nixpkgs#ssh-to-age --command bash -eu -c '
        SOPS_AGE_KEY="$(ssh-to-age -private-key -i "$HOME/.ssh/id_ed25519")"
        export SOPS_AGE_KEY
        # Closing the editor without changes is a successful no-op.
        sops "$@" || { status=$?; [[ "$status" -eq 200 ]] || exit "$status"; }
    ' -- "$@"
