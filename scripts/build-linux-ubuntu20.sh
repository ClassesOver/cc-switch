#!/usr/bin/env bash
set -euo pipefail

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required to build Ubuntu 20.04-compatible Linux packages." >&2
  exit 1
fi

BUNDLES="${1:-appimage,deb}"

docker run --rm \
  -v "$PWD:/work" \
  -w /work \
  -e CI=true \
  -e HOST_UID="$(id -u)" \
  -e HOST_GID="$(id -g)" \
  -e TAURI_SIGNING_PRIVATE_KEY \
  -e TAURI_SIGNING_PRIVATE_KEY_PASSWORD \
  -e CC_SWITCH_BUNDLES="$BUNDLES" \
  ubuntu:20.04 \
  bash -lc '
    set -euxo pipefail
    bash scripts/setup-linux-compat-env.sh
    export PATH="${CARGO_HOME:-$HOME/.cargo}/bin:$PATH"
    pnpm install --frozen-lockfile
    pnpm tauri build --bundles "$CC_SWITCH_BUNDLES"
    for path in /work/src-tauri/target /work/node_modules; do
      if [ -e "$path" ]; then
        chown -R "$HOST_UID:$HOST_GID" "$path"
      fi
    done
  '
