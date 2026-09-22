#!/usr/bin/env bash
#
# Copyright 2026 Kartik Gohil
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

ARCH="${1:-}"

case "$ARCH" in
    amd64|arm64)
        ;;
    *)
        echo "Usage: $0 <amd64|arm64>"
        exit 1
        ;;
esac

if [[ "$EUID" -ne 0 ]]; then
    echo "This script must be run as root."
    echo "Try: sudo $0 $ARCH"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/config.yml}"
WORK_DIR="${WORK_DIR:-$SCRIPT_DIR/.build/$ARCH}"
OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR/output}"

mkdir -p "$WORK_DIR" "$OUTPUT_DIR"

echo "==> Kairos build"
echo "==> Architecture: $ARCH"
echo "==> Config:       $CONFIG_FILE"
echo "==> Work dir:     $WORK_DIR"
echo

# ---------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------

echo "==> Installing build dependencies"

apt-get update

apt-get install -y \
    ca-certificates \
    curl \
    git \
    gpg \
    mksquashfs \
    python3 \
    python3-debian \
    python3-pip \
    python3-venv \
    python3-yaml \
    xorriso

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

read_config() {
    python3 - "$CONFIG_FILE" "$ARCH" "$1" <<'PY'
import sys
import yaml

config_file = sys.argv[1]
arch = sys.argv[2]
path = sys.argv[3].split(".")

with open(config_file, "r", encoding="utf-8") as f:
    config = yaml.safe_load(f)

value = config

for part in path:
    value = value[part]

if isinstance(value, dict) and arch in value:
    value = value[arch]

if value is None:
    raise SystemExit("Configuration value is empty")

if not isinstance(value, str):
    raise SystemExit(f"Configuration value is not a string: {sys.argv[3]}")

print(value)
PY
}

BASE_URL="$(read_config base.url)"
BASE_SHA256="$(read_config base.sha256)"

BASE_ISO="${WORK_DIR}/ubuntu.iso"

echo "==> Base image"
echo "    URL: $BASE_URL"

# ---------------------------------------------------------------------------
# Download and verify base image
# ---------------------------------------------------------------------------

download() {
    local url="$1"
    local destination="$2"

    curl \
        --fail \
        --location \
        --retry 5 \
        --retry-delay 5 \
        --output "$destination" \
        "$url"
}

verify_sha256() {
    local file="$1"
    local expected="$2"

    if [[ -z "$expected" ]]; then
        echo "WARNING: No SHA256 configured for $(basename "$file")"
        return 0
    fi

    echo "$expected  $file" | sha256sum --check -
}

if [[ ! -f "$BASE_ISO" ]]; then
    download "$BASE_URL" "$BASE_ISO"
fi

verify_sha256 "$BASE_ISO" "$BASE_SHA256"

# ---------------------------------------------------------------------------
# livefs-editor
# ---------------------------------------------------------------------------

LIVEFS_VENV="${WORK_DIR}/livefs-venv"

if [[ ! -x "${LIVEFS_VENV}/bin/livefs-edit" ]]; then
    echo "==> Installing livefs-editor"

    python3 -m venv "$LIVEFS_VENV"

    "${LIVEFS_VENV}/bin/pip" install --upgrade pip

    "${LIVEFS_VENV}/bin/pip" install \
        "git+https://github.com/mwhudson/livefs-editor.git"
fi

LIVEFS_EDIT="${LIVEFS_VENV}/bin/livefs-edit"

# ---------------------------------------------------------------------------
# Application configuration
# ---------------------------------------------------------------------------

APP_DIR="${WORK_DIR}/apps"
mkdir -p "$APP_DIR"

get_app_value() {
    local app="$1"
    local key="$2"

    python3 - "$CONFIG_FILE" "$app" "$key" <<'PY'
import sys
import yaml

config_file = sys.argv[1]
app = sys.argv[2]
key = sys.argv[3]

with open(config_file, "r", encoding="utf-8") as f:
    config = yaml.safe_load(f)

value = config["apps"][app][key]

if value is None:
    raise SystemExit("Configuration value is empty")

if not isinstance(value, str):
    raise SystemExit(f"Configuration value is not a string: apps.{app}.{key}")

print(value)
PY
}

get_app_sha256() {
    local app="$1"

    python3 - "$CONFIG_FILE" "$app" <<'PY'
import sys
import yaml

config_file = sys.argv[1]
app = sys.argv[2]

with open(config_file, "r", encoding="utf-8") as f:
    config = yaml.safe_load(f)

value = config["apps"][app].get("sha256", "")

if value is None:
    value = ""

if not isinstance(value, str):
    raise SystemExit(f"Invalid SHA256 for apps.{app}")

print(value)
PY
}

# ---------------------------------------------------------------------------
# OpenChamber
#
# OpenChamber's config entry is architecture-neutral. The architecture
# specific AppImage is resolved here, as an implementation detail.
# ---------------------------------------------------------------------------

resolve_openchamber() {
    local release_url="$1"

    curl \
        --fail \
        --location \
        --retry 5 \
        --retry-delay 5 \
        -sS \
        -H "Accept: application/vnd.github+json" \
        "$release_url" \
        | python3 - "$ARCH" <<'PY'
import json
import sys

arch = sys.argv[1]

patterns = {
    "amd64": ("linux-x64.AppImage",),
    "arm64": ("linux-arm64.AppImage",),
}

release = json.load(sys.stdin)

for asset in release.get("assets", []):
    name = asset["name"]

    if name.endswith(patterns[arch]):
        print(asset["browser_download_url"])
        break
else:
    raise SystemExit(
        f"No OpenChamber AppImage found for architecture: {arch}"
    )
PY
}

# ---------------------------------------------------------------------------
# Generate livefs-editor actions
# ---------------------------------------------------------------------------

ACTIONS_YAML="${WORK_DIR}/actions.yaml"
OPENCHAMBER_URL="$(get_app_value openchamber url)"
OPENCHAMBER_SHA256="$(get_app_sha256 openchamber)"
OPENCHAMBER_APPIMAGE="${APP_DIR}/OpenChamber.AppImage"

echo "==> Resolving OpenChamber for ${ARCH}"

OPENCHAMBER_ASSET_URL="$(
    resolve_openchamber "$OPENCHAMBER_URL"
)"

echo "    URL: $OPENCHAMBER_ASSET_URL"

download \
    "$OPENCHAMBER_ASSET_URL" \
    "$OPENCHAMBER_APPIMAGE"

verify_sha256 \
    "$OPENCHAMBER_APPIMAGE" \
    "$OPENCHAMBER_SHA256"

chmod 0755 "$OPENCHAMBER_APPIMAGE"

cat > "$ACTIONS_YAML" <<EOF
---
- name: setup-rootfs

- name: shell
  command: |
    set -eux

    chroot rootfs /bin/bash -c '
      export DEBIAN_FRONTEND=noninteractive

      apt-get update

      apt-get install -y \
        ca-certificates \
        curl \
        git \
        libfuse2t64

      rm -rf /var/lib/apt/lists/*
    '

- name: shell
  command: |
    set -eux

    chroot rootfs /bin/bash -c '
      export HOME=/root
      export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

      curl -fsSL "$(get_app_value ollama url)" | sh

      systemctl enable ollama.service || true
    '

- name: shell
  command: |
    set -eux

    chroot rootfs /bin/bash -c '
      export HOME=/root
      export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

      curl -fsSL "$(get_app_value opencode url)" | bash
    '

- name: cp
  source: ${OPENCHAMBER_APPIMAGE}
  dest: rootfs/opt/openchamber/OpenChamber.AppImage

- name: shell
  command: |
    set -eux

    mkdir -p rootfs/usr/share/applications

    chmod 0755 rootfs/opt/openchamber/OpenChamber.AppImage

    cat > rootfs/usr/share/applications/openchamber.desktop <<'DESKTOP'
[Desktop Entry]
Name=OpenChamber
Comment=Agentic development environment
Exec=env APPIMAGE_EXTRACT_AND_RUN=1 /opt/openchamber/OpenChamber.AppImage
Icon=application-x-executable
Terminal=false
Type=Application
Categories=Development;IDE;
StartupWMClass=OpenChamber
DESKTOP

    chmod 0644 rootfs/usr/share/applications/openchamber.desktop

- name: shell
  command: |
    set -eux

    chroot rootfs /bin/bash -c '
      rm -rf /var/lib/apt/lists/*
      rm -rf /tmp/*
    '
EOF

# ---------------------------------------------------------------------------
# Build ISO
# ---------------------------------------------------------------------------

OUTPUT_ISO="${OUTPUT_DIR}/kairos-${ARCH}.iso"

rm -f "$OUTPUT_ISO" "${OUTPUT_ISO}.sha256"

echo
echo "==> Building Kairos ISO"

"$LIVEFS_EDIT" \
    "$BASE_ISO" \
    "$OUTPUT_ISO" \
    --action-yaml "$ACTIONS_YAML"

if [[ ! -s "$OUTPUT_ISO" ]]; then
    echo "ERROR: Kairos ISO was not created."
    exit 1
fi

(
    cd "$OUTPUT_DIR"
    sha256sum "$(basename "$OUTPUT_ISO")" > "$(basename "$OUTPUT_ISO").sha256"
)

echo
echo "=============================================="
echo " Kairos build complete"
echo "=============================================="
echo
echo "ISO:"
echo "  $OUTPUT_ISO"
echo
echo "SHA256:"
cat "${OUTPUT_ISO}.sha256"
echo
