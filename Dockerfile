# ============================================================================
# Grablo IoT Core — runtime container image
# ----------------------------------------------------------------------------
# The Grablo binary is NOT committed to this repo. The image is built by
# downloading the official release .deb from the public CDN (downloads.grablo.co)
# and extracting its files (the package install scripts are not run).
#
# Build:
#   docker build --build-arg GRABLO_VERSION=1.20.0 -t ghcr.io/grablo/iot-core:1.20.0 .
#   (multi-arch builds are handled by .github/workflows/build-image.yml)
#
# Base image debian:11-slim (bullseye) matches the controller's build ABI.
# ============================================================================
FROM debian:11-slim

# Grablo version to fetch. The .deb architecture (amd64|arm64) is derived at build
# time from the image itself via `dpkg --print-architecture` — robust under buildx
# emulation and any builder that doesn't pass TARGETARCH.
ARG GRABLO_VERSION=1.20.0

ENV DEBIAN_FRONTEND=noninteractive \
    LD_LIBRARY_PATH=/usr/lib/grablo

# Marker the controller reads (IsRunningInContainer) to detect a containerized
# deployment → disables in-app OTA and reports `containerized` to the web app.
ENV GRABLO_CONTAINER=1

# OCI image metadata
LABEL org.opencontainers.image.title="Grablo IoT Core" \
      org.opencontainers.image.description="Grablo IoT Core controller as a Docker container — network/IoT/AI/remote-control alongside Home Assistant." \
      org.opencontainers.image.source="https://github.com/grablo/grablo-docker" \
      org.opencontainers.image.url="https://grablo.co" \
      org.opencontainers.image.vendor="Grablo" \
      org.opencontainers.image.version="${GRABLO_VERSION}" \
      org.opencontainers.image.licenses="LicenseRef-Proprietary"

# Runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
      vlc libvlc5 libxss1 libltdl7 libssh2-1 libcurl4 libatomic1 \
      libusb-1.0-0 libpq5 unixodbc libpulse0 libvulkan1 \
      pulseaudio pulseaudio-utils alsa-utils libharfbuzz0b libxml2 \
      libfreetype6 mosquitto ca-certificates curl \
      libxcursor1 libxinerama1 libxrandr2 libwayland-cursor0 \
      libgstreamer1.0-0 libgstreamer-plugins-base1.0-0 \
 && rm -rf /var/lib/apt/lists/*

# Download the public release .deb and extract its files (install scripts not run)
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    curl -fsSL -o /tmp/grablo.deb \
      "https://downloads.grablo.co/releases/grablo_${GRABLO_VERSION}_${arch}.deb"; \
    dpkg-deb -x /tmp/grablo.deb /tmp/grablo-root; \
    cp -a /tmp/grablo-root/usr/bin/grablo /usr/bin/; \
    cp -a /tmp/grablo-root/usr/lib/grablo /usr/lib/; \
    rm -rf /tmp/grablo.deb /tmp/grablo-root; \
    ldconfig /usr/lib/grablo

COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh \
 && chmod +x /entrypoint.sh /usr/bin/grablo/grablo

WORKDIR /usr/bin/grablo

# Liveness: grablo has reached the Grablo cloud (MQTT). Basic readiness signal —
# grablo runs as PID 1 so the container exits if it dies; this also flags
# "started but never connected" (broken network/cloud).
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD grep -q "MQTT connected" /var/log/grablo/log.txt 2>/dev/null || exit 1

ENTRYPOINT ["/entrypoint.sh"]
