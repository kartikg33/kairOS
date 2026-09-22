#!/usr/bin/env bash
#
# Copyright 2026 Kartik Gada
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

# ---------------------------------------------------------------------------
# Kairos MVP image builder
#
# Takes an official Ubuntu Desktop ISO and adds:
#   - Ollama
#   - OpenCode
#   - OpenChamber
#
# Usage:
#   ./build.sh amd64
#   ./build.sh arm64
#
# The script must be run on Linux as root or via sudo.
# ---------------------------------------------------------------------------

ARCH="${1:-}"

UBUNTU_VERSION="${UBUNTU_VERSION:-26.04.1}"
UBUNTU_RELEASE="${UBUNTU_RELEASE:-26.04}"

case "$ARCH" in
    amd64)
        UBUNTU_ARCH="amd64"
        ;;
    arm64)
        UBUNTU_ARCH="arm64"
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
WORK_DIR="${WORK_DIR:-$SCRIPT_DIR/.build/$ARCH}"
OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR/output}"

ISO_NAME="ubuntu-${UBUNTU_VERSION}-desktop-${UBUNTU_ARCH}.iso"
KAIROS_ISO="kairos-${UBUNTU_VERSION}-${ARCH}.iso"

UBUNTU_BASE_URL="https://cdimage.ubuntu.com/ubuntu/releases/${UBUNTU_RELEASE}/release"
UBUNTU_ISO_URL="${UBUNTU_BASE_URL}/${ISO_NAME}"
UBUNTU_SUMS_URL="${UBUNTU_BASE_URL}/SHA256SUMS"

mkdir -p "$WORK_DIR"
mkdir -p "$OUTPUT_DIR"

UBUNTU_ISO="${WORK_DIR}/${ISO_NAME}"
UBUNTU_SUMS="${WORK_DIR}/SHA256SUMS"
OPENCHAMBER_APPIMAGE="${WORK_DIR}/OpenChamber.AppImage"
ACTIONS_YAML="${WORK_DIR}/actions.yaml"
OUTPUT_ISO="${OUTPUT_DIR}/${KAIROS_ISO}"

echo "==> Building Kairos ${UBUNTU_VERSION} for ${ARCH}"
echo "==> Work directory: ${WORK_DIR}"
echo "==> Output: ${OUTPUT_ISO}"

# ---------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------

echo "==> Installing build dependencies..."

apt-get update

apt-get install -y \
    curl \
    git \
    gpg \
    mksquashfs \
    python3 \
    python3-debian \
    python3-venv \
    xorriso

# ---------------------------------------------------------------------------
# Install livefs-editor into an isolated virtual environment
# ---------------------------------------------------------------------------

LIVEFS_VENV="${WORK_DIR}/livefs-venv"

if [[ ! -x "${LIVEFS_VENV}/bin/livefs-edit" ]]; then
    echo "==> Installing livefs-editor..."

    python3 -m venv "$LIVEFS_VENV"

    "${LIVEFS_VENV}/bin/pip" install --upgrade pip
    "${LIVEFS_VENV}/bin/pip" install \
        "git+https://github.com/mwhudson/livefs-editor.git"
fi

LIVEFS_EDIT="${LIVEFS_VENV}/bin/livefs-edit"

# ---------------------------------------------------------------------------
# Download Ubuntu
# ---------------------------------------------------------------------------

if [[ ! -f "$UBUNTU_ISO" ]]; then
    echo "==> Downloading Ubuntu ${UBUNTU_VERSION} ${UBUNTU_ARCH}..."

    curl \
        --fail \
        --location \
        --retry 5 \
        --retry-delay 5 \
        --output "$UBUNTU_ISO" \
        "$UBUNTU_ISO_URL"
fi

echo "==> Downloading Ubuntu checksums..."

curl \
    --fail \
    --location \
    --retry 5 \
    --retry-delay 5 \
    --output "$UBUNTU_SUMS" \
    "$UBUNTU_SUMS_URL"

echo "==> Verifying Ubuntu ISO..."

(
    cd "$WORK_DIR"
    grep " ${ISO_NAME}\$" SHA256SUMS | sha256sum --check -
)

echo "==> Ubuntu ISO verified."

# ---------------------------------------------------------------------------
# Download OpenChamber
#
# OpenChamber publishes architecture-specific Linux AppImages through its
# GitHub releases. We resolve the latest stable release dynamically.
# ---------------------------------------------------------------------------

case "$ARCH" in
    amd64)
        OPENCHAMBER_PATTERN='linux-x64\.AppImage$'
        ;;
    arm64)
        OPENCHAMBER_PATTERN='linux-arm64\.AppImage$'
        ;;
esac

echo "==> Resolving latest OpenChamber release..."

OPENCHAMBER_URL="$(
    curl \
        --fail \
        --location \
        --retry 5 \
        --retry-delay 5 \
        -sS \
        https://api.github.com/repos/openchamber/openchamber/releases/latest \
    | python3 -c '
import json
import re
import sys

release = json.load(sys.stdin)
pattern = re.compile(sys.argv[1])

for asset in release["assets"]:
    name = asset["name"]
    if pattern.search(name):
        print(asset["browser_download_url"])
        break
else:
    raise SystemExit("No matching OpenChamber AppImage found")
' "$OPENCHAMBER_PATTERN"
)"

echo "==> OpenChamber: ${OPENCHAMBER_URL}"

curl \
    --fail \
    --location \
    --retry 5 \
    --retry-delay 5 \
    --output "$OPENCHAMBER_APPIMAGE" \
    "$OPENCHAMBER_URL"

chmod 0755 "$OPENCHAMBER_APPIMAGE"

# ---------------------------------------------------------------------------
# Create livefs-editor action file
# ---------------------------------------------------------------------------

cat > "$ACTIONS_YAML" <<EOF
---
# Install basic tools required by the bundled applications.
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

# -------------------------------------------------------------------------
# Ollama
# -------------------------------------------------------------------------

- name: shell
  command: |
    set -eux

    chroot rootfs /bin/bash -c '
      export HOME=/root
      export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

      curl -fsSL https://ollama.com/install.sh | sh

      systemctl enable ollama.service || true
    '

# -------------------------------------------------------------------------
# OpenCode
# -------------------------------------------------------------------------

- name: shell
  command: |
    set -eux

    chroot rootfs /bin/bash -c '
      export HOME=/root
      export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

      curl -fsSL https://opencode.ai/install | bash
    '

# -------------------------------------------------------------------------
# OpenChamber
# -------------------------------------------------------------------------

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

# -------------------------------------------------------------------------
# Kairos metadata
# -------------------------------------------------------------------------

- name: shell
  command: |
    set -eux

    mkdir -p rootfs/etc/kairos

    cat > rootfs/etc/kairos/release <<'RELEASE'
KAIROS_VERSION=${UBUNTU_VERSION}
KAIROS_ARCH=${ARCH}
UBUNTU_VERSION=${UBUNTU_VERSION}
RELEASE

    chmod 0644 rootfs/etc/kairos/release

# Clean package caches.
- name: shell
  command: |
    set -eux

    chroot rootfs /bin/bash -c '
      rm -rf /var/lib/apt/lists/*
      rm -rf /tmp/*
    '
EOF

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

rm -f "$OUTPUT_ISO"

echo "==> Building Kairos ISO..."

"$LIVEFS_EDIT" \
    "$UBUNTU_ISO" \
    "$OUTPUT_ISO" \
    --action-yaml "$ACTIONS_YAML"

# ---------------------------------------------------------------------------
# Verify output
# ---------------------------------------------------------------------------

if [[ ! -s "$OUTPUT_ISO" ]]; then
    echo "ERROR: Kairos ISO was not created."
    exit 1
fi

echo "==> Generating checksum..."

(
    cd "$OUTPUT_DIR"
    sha256sum "$KAIROS_ISO" > "${KAIROS_ISO}.sha256"
)

echo
echo "=============================================="
echo " Kairos build complete"
echo "=============================================="
echo
echo "ISO:"
echo "  ${OUTPUT_ISO}"
echo
echo "SHA256:"
cat "${OUTPUT_ISO}.sha256"
echo
