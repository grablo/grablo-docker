# Grablo IoT Core — Docker

Run [Grablo IoT Core](https://grablo.co) as a Docker container, next to a
Docker-based Home Assistant setup (mini-PC / NAS / Proxmox, etc.).

[Grablo](https://grablo.co) is a web-based, no-code platform for AI-powered IoT and
automation — build logic visually with blocks, add AI vision and audio, and control
everything from a web and mobile dashboard. In a container you get Grablo's network,
IoT, AI and automation features — MQTT, Modbus (RTU/TCP), OPC-UA, HTTP, Zigbee, AI
vision & audio, and Home Assistant integration — running right next to Home Assistant.

> **Access is through the [Grablo web app](https://app.grablo.co).** The container has
> no UI of its own — it connects to the Grablo cloud, and you pair and control it from
> the web app.

> **Running Home Assistant OS / Supervised?** Install the
> [Home Assistant add-on](https://github.com/grablo/grablo-hass-addons) instead — it
> sets up in one click and wires up hardware for you.

---

## Quick start

```bash
git clone https://github.com/grablo/grablo-docker.git
cd grablo-docker
docker compose up -d
```

Then open the [Grablo web app](https://app.grablo.co), pair the device that appears,
and control it.

Pin a specific version:

```bash
cp .env.example .env      # set GRABLO_VERSION
docker compose up -d
```

Update by pulling a newer image (the container does not self-update):

```bash
docker compose pull && docker compose up -d
```

---

## Persistent data

The container keeps its identity and data in named volumes (already set up in
`docker-compose.yml`) so it stays the **same paired device** across updates and
recreation:

| Volume | Path | Purpose |
|---|---|---|
| `grablo-id` | `/data` | Device identity — keep this to stay paired |
| `grablo-config` | `/etc/grablo` | Saved settings (incl. encrypted secure values) |
| `grablo-data` | `/var/grablo` | Downloaded user files / datalog |
| `grablo-log` | `/var/log/grablo` | Logs |
| `grablo-models` | `/usr/share/grablo` | AI / speech models + face-recognition data |
| `grablo-secure` | `/var/lib/.syscache` | Security keys for the encrypted settings |
| `grablo-zigbee` | `/usr/lib/grablo/zigbee` | Zigbee runtime (paired devices) |

> ⚠️ Don't delete `grablo-id` — without it the device must be re-paired and its saved
> settings are lost.

---

## Hardware & permissions

The container uses `network_mode: host` and needs outbound internet to reach the
Grablo cloud. **Network, cloud, AI-cloud and remote-control features then work out of
the box** — nothing extra to configure.

For *physical* hardware, grant each device in `docker-compose.yml` (uncomment the
relevant lines) — all **without `privileged`**:

| Feature | Add to `docker-compose.yml` |
|---|---|
| Audio (TTS / STT / media) | `devices: /dev/snd` + env `GRABLO_START_PULSE=1`, or mount the host PulseAudio socket |
| USB camera (AI video) | `devices: /dev/video0`, `/dev/media0` + `volumes: /run/udev:/run/udev:ro` |
| USB serial (Modbus RTU) | `devices: /dev/ttyUSB0` |
| Zigbee dongle | `devices: /dev/ttyACM0` |

- **USB cameras** are enumerated and captured via V4L2 — no libcamera, no `privileged`.
  (Verified on a Raspberry Pi 5 with a Logitech C922.)
- **Audio** is optional — if no sound device is attached, only audio features are
  disabled and everything else keeps working.

This is the standard way hardware-using Docker apps expose devices (the same as
Frigate, Zigbee2MQTT, ESPHome).

> - Device passthrough needs a **real Linux host** — Docker Desktop (Windows/macOS)
>   runs in a VM and can't pass USB devices through.
> - **CSI cameras** (Pi Camera Module) need libcamera + `privileged` and are out of
>   scope — use a USB camera, or run Grablo natively.

---

## How it works

Images are published to `ghcr.io/grablo/iot-core` (multi-arch `amd64` / `arm64`). Each
image is built by fetching the official release `.deb` from the public CDN — the
Grablo binary is never committed to this repo. You can build it yourself:

```bash
docker build --build-arg GRABLO_VERSION=1.20.0 -t ghcr.io/grablo/iot-core:1.20.0 .
```

---

## Logs

```bash
docker logs -f grablo
```

grablo logs to a file, mirrored to the container stdout. Set `GRABLO_LOG_STDOUT=0` to
disable the mirror.

---

## Supported architectures

`linux/amd64`, `linux/arm64`. (32-bit armv7 is not supported.)

---

## Links

- Website: **https://grablo.co**
- Web app: **https://app.grablo.co**
- Template gallery: **https://app.grablo.co/gallery**
- Documentation: **https://doc.grablo.co**
- Home Assistant add-on: **https://github.com/grablo/grablo-hass-addons**

---

## License

This repository contains only distribution packaging (Dockerfile / compose). The
Grablo IoT Core software itself is under Grablo's proprietary license.
