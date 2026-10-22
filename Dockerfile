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
# Base image: debian:13-slim (trixie).
#
# Was debian:11-slim (bullseye) on the theory that it had to match the
# controller's build ABI. Measured 2026-09-22 — it does not:
#
#   · the binary needs at most GLIBC_2.30 (bullseye itself ships 2.31), so any
#     newer base satisfies it — glibc is backward compatible in this direction
#   · of the 78 SONAMEs it needs, 64 are bundled in /usr/lib/grablo (141 files);
#     only 14 come from this image, and all 14 resolve on trixie
#     (the one that could have moved is libvlc.so.5 — trixie is still VLC 3.x)
#   · the 27 runtime packages below all resolve on bookworm and trixie
#
# The move was forced: Debian 11 is now oldoldstable and its security suite is
# mid-migration to the archive — the bullseye-security *index* is still served
# while its *pool* is empty, so `apt-get install` fetches a 404 and the build
# dies. Nothing we could pin around (checked deb.debian.org, security.debian.org,
# archive.debian.org and two mirrors; snapshot.debian.org works but freezes us
# in the past). trixie is current stable and matches the Raspberry Pi images we
# already ship (rpios_trixie).
#
# The controller's own builder (docker/builder in grablo-controller) stays on
# bullseye — 141 bundled libraries are matched to it there, and its output runs
# on later releases anyway. That is a different decision from this one.
# ============================================================================
FROM debian:13-slim

# Grablo version to fetch. The .deb architecture (amd64|arm64) is derived at build
# time from the image itself via `dpkg --print-architecture` — robust under buildx
# emulation and any builder that doesn't pass TARGETARCH.
ARG GRABLO_VERSION=1.20.0

# Product (one controller source, version numbers per product — grablo-frontend docs/SPOT_RELEASE_CHANNEL.md):
#   core → ghcr.io/grablo/iot-core  (Reflex / Studio, 1.x)  from releases/grablo_<ver>_<arch>.deb
#   spot → ghcr.io/grablo/spot      (Grablo Spot, 2.x)      from releases/spot/grablo-spot_<ver>_<arch>.deb
#          (the Spot deb adds /usr/share/grablo/product.json → the controller knows it is the Spot edition)
ARG GRABLO_PRODUCT=core
ARG GRABLO_TITLE="Grablo IoT Core"

ENV DEBIAN_FRONTEND=noninteractive \
    LD_LIBRARY_PATH=/usr/lib/grablo

# Marker the controller reads (IsRunningInContainer) to detect a containerized
# deployment → disables in-app OTA and reports `containerized` to the web app.
ENV GRABLO_CONTAINER=1

# OCI image metadata
LABEL org.opencontainers.image.title="${GRABLO_TITLE}" \
      org.opencontainers.image.description="${GRABLO_TITLE} controller as a Docker container — network/IoT/AI/remote-control alongside Home Assistant." \
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
      libxcursor1 libxinerama1 libxrandr2 libxi6 libwayland-cursor0 \
      libgstreamer1.0-0 libgstreamer-plugins-base1.0-0 \
 && rm -rf /var/lib/apt/lists/*
# ★ libxi6 는 2026-09-22 trixie 전환에서 **명시로 옮긴 것**이다. bullseye 에서는
#   다른 패키지의 전이 의존으로 딸려와 목록에 없어도 됐는데, trixie 에서 그 체인이
#   끊겨 `libXi.so.6 => not found` 가 났다(grablo 본체와 libgrablo-media.so 둘 다).
#   배포 중인 1.29.1(bullseye) 이미지는 미해결 0 건이라 이것은 전환이 만든 회귀다.
#   전이 의존에 기대면 베이스가 바뀔 때마다 같은 일이 난다 — 필요한 것은 적어 둔다.

# Download the public release .deb and extract its files (install scripts not run)
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "${GRABLO_PRODUCT}" in \
      core) url="https://downloads.grablo.co/releases/grablo_${GRABLO_VERSION}_${arch}.deb" ;; \
      spot) url="https://downloads.grablo.co/releases/spot/grablo-spot_${GRABLO_VERSION}_${arch}.deb" ;; \
      *) echo "GRABLO_PRODUCT must be core or spot" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/grablo.deb "$url"; \
    dpkg-deb -x /tmp/grablo.deb /tmp/grablo-root; \
    cp -a /tmp/grablo-root/usr/bin/grablo /usr/bin/; \
    cp -a /tmp/grablo-root/usr/lib/grablo /usr/lib/; \
    cp -a /tmp/grablo-root/usr/share/grablo /usr/share/; \
    # Image-owned copy of what must follow the image, not the volume: compose mounts a volume on /usr/share/grablo
    # (models, face DB), which hides the image's local screen (www/spot) and edition marker (product.json) after the
    # first run. entrypoint.sh copies these back on every start.
    mkdir -p /opt/grablo-image; \
    cp -a /tmp/grablo-root/usr/share/grablo/www /opt/grablo-image/www 2>/dev/null || true; \
    cp -a /tmp/grablo-root/usr/share/grablo/product.json /opt/grablo-image/product.json 2>/dev/null || true; \
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
