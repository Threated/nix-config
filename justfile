set positional-arguments
set dotenv-load

# List available commands.
default:
    @just --list

# Deploy the current committed/pushed revision using the Pi's private repositories.
deploy-rpi:
    #!/usr/bin/env bash
    set -euo pipefail
    revision=$(git rev-parse HEAD)
    ssh -o BatchMode=yes threated@rpi sudo -n systemctl restart "nix-config-deploy@$revision.service"

# Push committed private sources to the Pi for the next CI deployment.
push-rpi-inputs assistant=env("ASSISTANT_PATH", "") hue_music=env("HUE_MUSIC_PATH", ""):
    #!/usr/bin/env bash
    set -euo pipefail
    test -n "$1" && test -n "$2"
    git -C "$1" push rpi HEAD:refs/heads/main
    git -C "$2" push rpi HEAD:refs/heads/main

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
