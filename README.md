# Grablo IoT Core — Docker

Run [Grablo IoT Core](https://grablo.co) as a Docker container, next to a
Docker-based Home Assistant setup (mini-PC / NAS / Proxmox, etc.).

[Grablo](https://grablo.co) is a web-based, no-code platform for AI-powered IoT and
automation. You build logic visually with blocks, add AI vision and audio, and control
everything from a web and mobile dashboard. In a container you get Grablo's network,
IoT, AI and automation features (MQTT, Modbus, OPC-UA, HTTP, Zigbee, AI vision and
audio, Home Assistant integration).

> **Access is through the [Grablo web app](https://app.grablo.co).** The container has
> no UI of its own. You connect to it and control it from the web app.

> **Running Home Assistant OS / Supervised?** Use the
> [Home Assistant add-on](https://github.com/grablo/grablo-hass-addons) instead. It
> installs in one click and sets up hardware for you.

---

## Quick start

```bash
git clone https://github.com/grablo/grablo-docker.git
cd grablo-docker
docker compose up -d
```

Then open the [Grablo web app](https://app.grablo.co), connect to your device, and
start building.

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
`docker-compose.yml`) so it stays the **same device** across updates and recreation.

| Volume | Path | Purpose |
|---|---|---|
| `grablo-id` | `/data` | Device identity (keep this so it stays the same device) |
| `grablo-config` | `/etc/grablo` | Saved settings (incl. encrypted secure values) |
| `grablo-data` | `/var/grablo` | Downloaded user files / datalog |
| `grablo-log` | `/var/log/grablo` | Logs |
| `grablo-models` | `/usr/share/grablo` | AI / speech models + face-recognition data |
| `grablo-secure` | `/var/lib/.syscache` | Security keys for the encrypted settings |
| `grablo-zigbee` | `/usr/lib/grablo/zigbee` | Zigbee runtime (paired devices) |

> ⚠️ Don't delete `grablo-id`. Without it the device gets a new identity and must be
> added again in the web app.

---

## Hardware & permissions

The container uses `network_mode: host` and needs outbound internet so you can reach
it from the web app. Network, IoT, AI and remote-control features then work with no
extra configuration.

For *physical* hardware, grant each device in `docker-compose.yml` (uncomment the
relevant lines). None of this needs `privileged`:

| Feature | Add to `docker-compose.yml` |
|---|---|
| Audio (TTS / STT / media) | `devices: /dev/snd` + env `GRABLO_START_PULSE=1`, or mount the host PulseAudio socket |
| USB camera (AI video) | `devices: /dev/video0`, `/dev/media0` + `volumes: /run/udev:/run/udev:ro` |
| USB serial (Modbus RTU) | `devices: /dev/ttyUSB0` |
| Zigbee dongle | `devices: /dev/ttyACM0` |

USB cameras work via V4L2, with no `privileged` mode needed (verified on a Raspberry
Pi 5). Audio is optional: with no sound device, only audio features are disabled.

> Device passthrough needs a real Linux host. Docker Desktop (Windows/macOS) runs in a
> VM and cannot pass USB devices through. CSI cameras (Pi Camera Module) need libcamera
> and `privileged`, so use a USB camera or run Grablo natively.

---

## How it works

Images are published to `ghcr.io/grablo/iot-core` (multi-arch `amd64` / `arm64`). Each
image is built by fetching the official release `.deb` from the public CDN, so the
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
- Project gallery: **https://app.grablo.co/gallery**
- Documentation: **https://doc.grablo.co**
- Home Assistant add-on: **https://github.com/grablo/grablo-hass-addons**

---

## License

This repository contains only distribution packaging (Dockerfile / compose). The
Grablo IoT Core software itself is under Grablo's proprietary license.
