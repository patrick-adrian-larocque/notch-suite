#!/usr/bin/env bash
# Codex Cloud install entry point. Installs native Swift; no Docker daemon needed.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [[ "$(uname -s)" != Linux ]]; then
  echo "Cloud setup requires Linux. On macOS use ./script/setup.sh." >&2
  exit 1
fi

# Match CI's swift:6.4-noble image. Swift reports 6.4 for the 6.4.0 release.
swift_version=6.4.0
if command -v swift >/dev/null &&
  swift --version | grep -Eq 'Swift version 6\.4(\.0)?( |$)' &&
  swift format --help >/dev/null && command -v lldb >/dev/null; then
  echo "Using the installed Swift $swift_version toolchain."
else
  # Official release archives are distribution- and architecture-specific.
  source /etc/os-release
  if [[ "$ID" != ubuntu || "$VERSION_ID" != 24.04 ]]; then
    echo "Automatic Swift installation supports Ubuntu 24.04. Install Swift $swift_version and LLDB for this distribution, then rerun." >&2
    exit 1
  fi
  case "$(uname -m)" in
    x86_64) platform=ubuntu2404; archive_platform=ubuntu24.04 ;;
    aarch64) platform=ubuntu2404-aarch64; archive_platform=ubuntu24.04-aarch64 ;;
    *) echo "Unsupported Linux architecture: $(uname -m)." >&2; exit 1 ;;
  esac

  as_root=()
  if [[ "$EUID" != 0 ]]; then
    if ! command -v sudo >/dev/null || ! sudo -n true; then
      echo "Installing Swift requires root or passwordless sudo." >&2
      exit 1
    fi
    as_root=(sudo -n)
  fi

  "${as_root[@]}" apt-get update -qq
  "${as_root[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates curl gnupg binutils git libc6-dev libcurl4-openssl-dev \
    libedit2 libgcc-13-dev libicu-dev libncurses-dev libpython3-dev \
    libsqlite3-0 libstdc++-13-dev libxml2-dev libz3-dev pkg-config \
    tzdata zip unzip zlib1g-dev ripgrep

  install_dir="/opt/notch-suite/swift-$swift_version"
  if [[ -e "$install_dir" ]]; then
    echo "$install_dir already exists but its toolchain is not usable on PATH. Restore its /usr/local/bin links or inspect the incomplete installation before retrying." >&2
    exit 1
  fi
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' EXIT
  archive="swift-$swift_version-RELEASE-$archive_platform.tar.gz"
  download_url="https://download.swift.org/swift-$swift_version-release/$platform/swift-$swift_version-RELEASE/$archive"
  curl --fail --silent --show-error --location --retry 3 --connect-timeout 30 "$download_url" -o "$temp_dir/$archive"
  curl --fail --silent --show-error --location --retry 3 --connect-timeout 30 "$download_url.sig" -o "$temp_dir/$archive.sig"
  curl --fail --silent --show-error --compressed --location --retry 3 --connect-timeout 30 https://www.swift.org/keys/all-keys.asc -o "$temp_dir/swift-keys.asc"
  mkdir -m 700 "$temp_dir/gnupg"
  gpg --batch --homedir "$temp_dir/gnupg" --import "$temp_dir/swift-keys.asc"
  gpg --batch --homedir "$temp_dir/gnupg" --verify "$temp_dir/$archive.sig" "$temp_dir/$archive"

  mkdir "$temp_dir/toolchain"
  tar -xzf "$temp_dir/$archive" --strip-components=1 -C "$temp_dir/toolchain"
  "${as_root[@]}" mkdir -p /opt/notch-suite /usr/local/bin
  "${as_root[@]}" mv "$temp_dir/toolchain" "$install_dir"
  # Persist across task shells, which don't inherit exports from this script.
  for tool in swift swiftc swift-format lldb sourcekit-lsp; do
    "${as_root[@]}" ln -sfn "$install_dir/usr/bin/$tool" "/usr/local/bin/$tool"
  done
  export PATH="/usr/local/bin:$PATH"
  hash -r
fi

swift --version
swift format --help >/dev/null
lldb --version
./script/setup.sh
echo "Cloud setup complete. Run ./script/verify.sh to build, test, and lint."
