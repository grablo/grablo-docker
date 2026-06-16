#!/bin/bash
# ============================================================================
# Grablo container entrypoint
#   Does only what the container needs at startup, then runs grablo as PID 1.
# ============================================================================
set -e

DATA_DIR="${GRABLO_DATA_DIR:-/data}"

# 1) Device identity persistence
#    Keep the device identity stable across container recreation so it stays the
#    same paired device. Without it, the device must be re-paired.
if [ -s "${DATA_DIR}/machine-id" ]; then
    cp "${DATA_DIR}/machine-id" /etc/machine-id
elif [ ! -s /etc/machine-id ]; then
    cat /proc/sys/kernel/random/uuid | tr -d '-' > /etc/machine-id
    if [ -d "${DATA_DIR}" ] || mkdir -p "${DATA_DIR}" 2>/dev/null; then
        cp /etc/machine-id "${DATA_DIR}/machine-id" 2>/dev/null || true
    fi
fi
echo "[entrypoint] device identity ready"

# 2) Library cache
ldconfig /usr/lib/grablo 2>/dev/null || true

# 3) Audio
#    By default an external PulseAudio (host socket mount, or HA audio:true) is used.
#    Set GRABLO_START_PULSE=1 (with /dev/snd) to start PulseAudio inside the container.
if [ "${GRABLO_START_PULSE}" = "1" ] && command -v pulseaudio >/dev/null 2>&1; then
    echo "[entrypoint] starting in-container PulseAudio (system mode)..."
    pulseaudio --system --disallow-exit --disallow-module-loading=0 --daemonize=yes --realtime 2>/dev/null || \
        echo "[entrypoint] WARN: failed to start pulseaudio — audio disabled"
fi
[ -n "${PULSE_SERVER}" ] && echo "[entrypoint] PULSE_SERVER=${PULSE_SERVER}"

# 4) Remove stale single-instance lock.
#    grablo records its PID in /run/grablo.pid. In a container it runs as PID 1,
#    and /run persists across restarts, so a leftover lock (PID 1 is "always alive")
#    makes the next start abort with "another instance is already running".
#    Only one grablo ever runs in this container, so any lock present here is stale.
rm -f /run/grablo.pid

# 5) Mirror grablo's file log to the container stdout so `docker logs` works.
#    (grablo logs to /var/log/grablo/log.txt by default.) tail -F retries until
#    the file appears and follows rotation. Opt out with GRABLO_LOG_STDOUT=0.
if [ "${GRABLO_LOG_STDOUT:-1}" = "1" ]; then
    tail -n0 -F /var/log/grablo/log.txt 2>/dev/null &
fi

# 6) Run grablo as PID 1.
echo "[entrypoint] exec grablo ..."
exec /usr/bin/grablo/grablo
