#!/usr/bin/env bash
set -euo pipefail

if ! command -v apt-get >/dev/null 2>&1; then
  echo "This script expects a Debian/Ubuntu environment with apt-get." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  git \
  xz-utils \
  build-essential \
  python3 \
  pkg-config \
  file \
  wget \
  patchelf \
  rpm \
  xdg-utils \
  libssl-dev \
  libxdo-dev \
  libgtk-3-dev \
  librsvg2-dev \
  libayatana-appindicator3-dev \
  libwebkit2gtk-4.0-dev \
  libsoup2.4-dev

if [[ "${CC_SWITCH_SKIP_NODE:-0}" != "1" ]]; then
  node_major=""
  if command -v node >/dev/null 2>&1; then
    node_major="$(node -p "process.versions.node.split('.')[0]")"
  fi

  if [[ "$node_major" != "20" ]]; then
    case "$(uname -m)" in
      x86_64)
        node_arch="x64"
        ;;
      aarch64|arm64)
        node_arch="arm64"
        ;;
      *)
        echo "Unsupported architecture for Node.js bootstrap: $(uname -m)" >&2
        exit 1
        ;;
    esac

    node_tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$node_tmp_dir"' EXIT
    curl -fsSL "https://nodejs.org/dist/latest-v20.x/SHASUMS256.txt" -o "$node_tmp_dir/SHASUMS256.txt"
    node_archive="$(awk '/linux-'"$node_arch"'\\.tar\\.xz$/ { print $2; exit }' "$node_tmp_dir/SHASUMS256.txt")"
    if [[ -z "$node_archive" ]]; then
      echo "Unable to resolve a Node.js 20 archive for linux-$node_arch." >&2
      exit 1
    fi

    curl -fsSL "https://nodejs.org/dist/latest-v20.x/$node_archive" -o "$node_tmp_dir/$node_archive"
    install -d /usr/local/lib/nodejs
    tar -xJf "$node_tmp_dir/$node_archive" -C /usr/local/lib/nodejs

    node_install_dir="/usr/local/lib/nodejs/${node_archive%.tar.xz}"
    ln -sf "$node_install_dir/bin/node" /usr/local/bin/node
    ln -sf "$node_install_dir/bin/npm" /usr/local/bin/npm
    ln -sf "$node_install_dir/bin/npx" /usr/local/bin/npx
    ln -sf "$node_install_dir/bin/corepack" /usr/local/bin/corepack
    rm -rf "$node_tmp_dir"
    trap - EXIT
  fi

  corepack enable
  corepack prepare pnpm@10.12.3 --activate
fi

if [[ "${CC_SWITCH_SKIP_RUST:-0}" != "1" ]]; then
  export CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}"
  export RUSTUP_HOME="${RUSTUP_HOME:-$HOME/.rustup}"
  export PATH="$CARGO_HOME/bin:$PATH"

  if ! command -v rustup >/dev/null 2>&1; then
    curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal
  fi

  rustup set profile minimal
  rustup toolchain install stable --no-self-update

  if [[ -n "${CC_SWITCH_RUST_COMPONENTS:-}" ]]; then
    IFS=' ' read -r -a rust_components <<< "${CC_SWITCH_RUST_COMPONENTS}"
    rustup component add "${rust_components[@]}" --toolchain stable
  fi

  rustup default stable
fi
