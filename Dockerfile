# Copyright 2026 Kartik Gohil
# SPDX-License-Identifier: Apache-2.0

FROM fedora:latest

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    DISPLAY=:99 \
    HOME=/home/kair

# ------------------------------------------------------------
# Base desktop + runtime
# ------------------------------------------------------------

RUN dnf -y update && \
    dnf -y install \
        @xfce-desktop-environment \
        dbus-x11 \
        xorg-x11-server-Xvfb \
        x11vnc \
        wget \
        curl \
        git \
        git-lfs \
        jq \
        sudo \
        tar \
        gzip \
        unzip \
        ca-certificates \
        fontconfig \
        dejavu-sans-fonts \
        dejavu-serif-fonts \
        mesa-dri-drivers \
        libX11 \
        libXcomposite \
        libXdamage \
        libXext \
        libXfixes \
        libXi \
        libXrandr \
        libXtst \
        libxcb \
        libxkbcommon \
        libxkbcommon-x11 \
        novnc \
        python3 \
    && dnf clean all \
    && rm -rf /var/cache/dnf

# ------------------------------------------------------------
# User
# ------------------------------------------------------------

RUN useradd -m -s /bin/bash kair && \
    echo "kair ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/kair && \
    chmod 0440 /etc/sudoers.d/kair

# ------------------------------------------------------------
# Node.js
# ------------------------------------------------------------

RUN curl -fsSL https://rpm.nodesource.com/setup_24.x | bash - && \
    dnf -y install nodejs && \
    dnf clean all && \
    rm -rf /var/cache/dnf

# ------------------------------------------------------------
# OpenClaw
# ------------------------------------------------------------

RUN npm install -g openclaw@latest

# Install Matrix plugin
RUN openclaw plugins install @openclaw/matrix

# ------------------------------------------------------------
# Element Desktop
#
# Official Element Linux tarball.
# ------------------------------------------------------------

ARG ELEMENT_VERSION=1.12.29
ARG TARGETARCH

RUN mkdir -p /opt/element && \
    case "${TARGETARCH}" in \
        amd64) ELEMENT_ARCH="x86-64"; ELEMENT_FILE="element-desktop-${ELEMENT_VERSION}.tar.gz" ;; \
        arm64) ELEMENT_ARCH="aarch64"; ELEMENT_FILE="element-desktop-${ELEMENT_VERSION}-arm64.tar.gz" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    curl -fsSL \
      "https://packages.element.io/desktop/install/linux/glibc-${ELEMENT_ARCH}/${ELEMENT_FILE}" \
      -o /tmp/element.tar.gz && \
    tar -xzf /tmp/element.tar.gz \
      --strip-components=1 \
      -C /opt/element && \
    rm /tmp/element.tar.gz && \
    ln -s /opt/element/element-desktop /usr/local/bin/element

RUN mkdir -p /usr/share/applications && \
    cat > /usr/share/applications/element.desktop <<'EOF'
[Desktop Entry]
Name=Element
Comment=Matrix client
Exec=/usr/local/bin/element
Terminal=false
Type=Application
Categories=Network;Chat;
EOF

# ------------------------------------------------------------
# kairOS filesystem
# ------------------------------------------------------------

RUN mkdir -p \
        /home/kair/workspaces \
        /home/kair/.config \
        /home/kair/.openclaw \
    && chown -R kair:kair /home/kair

# ------------------------------------------------------------
# XFCE defaults
# ------------------------------------------------------------

RUN cat > /etc/xdg/autostart/kair-element.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Element
Exec=/usr/local/bin/element --disable-gpu
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

# ------------------------------------------------------------
# Startup
# ------------------------------------------------------------

COPY entrypoint.sh /usr/local/bin/kair-entrypoint
RUN chmod +x /usr/local/bin/kair-entrypoint

USER kair

WORKDIR /home/kair

EXPOSE 6080 5900 18789

ENTRYPOINT ["/usr/local/bin/kair-entrypoint"]