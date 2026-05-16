#!/bin/bash
set -euo pipefail

IMAGE=${MKDOCS_IMAGE:-mkdocs}
DOCS_DIR=${DOCS_DIR:-$(pwd)}

if [ -z "${SSH_AUTH_SOCK:-}" ]; then
    echo "ERROR: SSH_AUTH_SOCK is not set. Start ssh-agent and run ssh-add first." >&2
    exit 1
fi

args=(--rm -it -p 8000:8000)

case "$(uname -s)" in
    Darwin)
        # macOS: Podman Machine proxies the SSH auth socket from the host into the VM
        # No SELinux labels needed
        args+=(
            -v "${DOCS_DIR}:/docs"
            -v "${HOME}/.gitconfig:/root/.gitconfig:ro"
            -e "SSH_AUTH_SOCK=${SSH_AUTH_SOCK}"
            -v "${SSH_AUTH_SOCK}:${SSH_AUTH_SOCK}"
        )
        ;;
    Linux)
        # Fedora: :Z relabels volumes for SELinux
        args+=(
            -v "${DOCS_DIR}:/docs:Z"
            -v "${HOME}/.gitconfig:/root/.gitconfig:ro,Z"
            -e "SSH_AUTH_SOCK=${SSH_AUTH_SOCK}"
            -v "${SSH_AUTH_SOCK}:${SSH_AUTH_SOCK}:Z"
        )
        ;;
    *)
        echo "ERROR: Unsupported OS: $(uname -s)" >&2
        exit 1
        ;;
esac

exec podman run "${args[@]}" "$IMAGE"
