# Grablo IoT Core — Docker

Run [Grablo IoT Core](https://grablo.co) as a Docker container, next to a
Docker-based Home Assistant setup (mini-PC / NAS / Proxmox, etc.).

[Grablo](https://grablo.co) is a web-based, no-code platform for AI-powered IoT —
build logic by placing blocks instead of writing code, add AI vision and audio
without machine-learning expertise, and control everything from a web and mobile
dashboard, anywhere, with no extra setup. In a container you get Grablo's network,
IoT, AI and remote-control features (MQTT, Modbus, OPC-UA, HTTP, AI vision and audio,
USB camera, USB serial) running right beside Home Assistant.

> **Access is through the existing [Grablo web app](https://app.grablo.co).** The
> container does not serve its own UI — it connects to the Grablo cloud, and you
> pair and control it from the web app.

---

## Quick start

```bash
git clone https://github.com/grablo/grablo-docker.git
cd grablo-docker
docker compose up -d
```

Once the container connects to the cloud, log in to the
[Grablo web app](https://app.grablo.co), pair the device that appears, and control it.

To pin a specific version:

```bash
cp .env.example .env      # edit GRABLO_VERSION
docker compose up -d
```

---

## How it works

- Images are published to the **GitHub Container Registry**: `ghcr.io/grablo/iot-core`.
- Each image is built by downloading the official release `.deb` from the public
  CDN (`downloads.grablo.co`) and packaging it (see `Dockerfile`). You can build it
  yourself too:

  ```bash
  docker build --build-arg GRABLO_VERSION=1.20.0 -t ghcr.io/grablo/iot-core:1.20.0 .
  ```

This repository contains only the packaging recipe. The Grablo IoT Core binary
is never committed here — it is fetched at build time from the public CDN.

---

## Persistent data (important)

For the container to stay the **same device** across recreation, it needs volumes.
`docker-compose.yml` persists the following as named volumes:

| Volume | Path | Purpose |
|---|---|---|
| `grablo-id` | `/data` | Device identity — keep this to stay paired |
| `grablo-config` | `/etc/grablo` | Saved settings (incl. encrypted secure values) |
| `grablo-data` | `/var/grablo` | Downloaded user files / datalog |
| `grablo-log` | `/var/log/grablo` | Logs |
| `grablo-models` | `/usr/share/grablo` | AI / speech / LPR models + face-recognition DB |
| `grablo-secure` | `/var/lib/.syscache` | Security key/salt for the encrypted secure values |
| `grablo-zigbee` | `/usr/lib/grablo/zigbee` | Zigbee runtime (incl. paired devices) |

> ⚠️ If `grablo-id` is lost, the device must be **re-paired** and its saved settings
> are lost. Do not delete it.

---

## Networking

The container uses `network_mode: host` for real-time connectivity (recommended on
a real Linux host). It needs **outbound internet** access to the Grablo cloud.

---

## Hardware & permissions

A container only gets the hardware you explicitly grant it. **Network, cloud, remote
control and AI-cloud features need nothing extra** — they work out of the box. For
*physical* hardware, add the matching lines to `docker-compose.yml` (one per device):

| Feature | Add to `docker-compose.yml` | `privileged`? |
|---|---|---|
| Network / cloud / remote / AI-cloud | nothing — works by default | No |
| Audio (TTS / STT / media) | `devices: /dev/snd` + env `GRABLO_START_PULSE=1`, or mount the host PulseAudio socket | No |
| USB camera (AI video) | `devices: /dev/video0`, `/dev/media0` + `volumes: /run/udev:/run/udev:ro` | No |
| USB serial (Modbus RTU) | `devices: /dev/ttyUSB0` | No |
| Zigbee dongle | `devices: /dev/ttyACM0` | No |

Everything above works **without `privileged`**. See the commented blocks in
`docker-compose.yml`, and the Audio / Camera sections below for details.

> **Device passthrough needs a real Linux host.** Docker Desktop (Windows/macOS) runs
> in a VM and cannot pass host USB devices through.
>
> **CSI cameras** (Pi Camera Module) need libcamera + `privileged` and are out of
> scope — use a USB camera, or run Grablo natively.
>
> Prefer not to wire devices yourself? The
> **[Home Assistant add-on](https://github.com/grablo/grablo-hass-addons)** declares
> these permissions in its manifest and the Supervisor attaches the devices for you.

---

## Audio (optional)

To use audio features (TTS / STT / media), attach a host sound device by
uncommenting the audio section in `docker-compose.yml`:

- **Desktop host (PulseAudio):** mount the host socket and set `PULSE_SERVER`.
- **Server (direct ALSA):** pass through `/dev/snd` and set `GRABLO_START_PULSE=1`.

If no audio device is available, only audio features are disabled — everything else
works normally. (Verified on a real host: TTS / STT / media playback all work.)

---

## Camera (AI video)

Attach a USB camera by passing its device nodes in `docker-compose.yml`:

```yaml
    devices:
      - /dev/video0
      - /dev/media0
    volumes:
      - /run/udev:/run/udev:ro    # device enumeration
```

A USB camera then scans and streams **without `privileged`** — verified on a
Raspberry Pi 5 (Logitech C922). In a container the controller enumerates and
captures USB cameras via V4L2 directly (no libcamera), so only the device nodes
above are needed.

> **CSI cameras** (Pi Camera Module) are different: they need libcamera (the ISP
> pipeline), which in a container requires `privileged` + more device passthrough.
> CSI is out of scope here — use a USB camera, or run grablo natively for CSI.
>
> Older controllers (≤ 1.19.0) enumerated USB cameras via libcamera and needed
> `privileged`; controller 1.19.2+ removes that with the V4L2 path.

---

## Logs

The controller logs to a file, mirrored to the container stdout, so:

```bash
docker logs -f grablo
```

(Disable the mirror with `GRABLO_LOG_STDOUT=0` if you only want the file log.)

---

## Supported architectures

`linux/amd64`, `linux/arm64`. (32-bit armv7 is not supported.)

---

## Updating

Containers update by **pulling a new image**, not via in-app updates:

```bash
docker compose pull && docker compose up -d
```

Using the `latest` tag pulls the newest published image at pull time. To stay on a
fixed version, pin `GRABLO_VERSION` in `.env`.

---

## Scope / roadmap

- ✅ Network / IoT / cloud, web access, Device ID & settings persistence
- ✅ Restart safety (single-instance via flock) + container-aware updates (in-app OTA
  disabled in a container → update by image pull)
- ✅ Audio I/O (TTS / STT / media) — verified on a real host (Raspberry Pi 5)
- ✅ USB camera (AI video) — scans & streams **without `privileged`** (V4L2, controller
  1.19.2+) — verified on Raspberry Pi 5
- ⏳ USB serial / Zigbee / Modbus RTU dongles (pending validation)
- ✅ Home Assistant add-on — published separately:
  [grablo-hass-addons](https://github.com/grablo/grablo-hass-addons) (one-click
  install, auto-auth via the Supervisor — no token needed)
- ✖ GPIO / I2C / SPI direct hardware — not relevant on x86 (ARM SBC: future);
  local display output — not relevant for headless

---

## FAQ

**Do I need a separate device to run this?**
No. Run it as a container next to your Home Assistant (same mini-PC / NAS / Proxmox).
It connects to the Grablo cloud and you control it from the web app.

**It's a container, not a VM — do I have to map `/dev/...` devices myself?**
For network / cloud / AI-cloud features: **no**, they work out of the box. For
*physical* hardware (camera, USB serial, audio) you add one `devices:` line per
device — see [Hardware & permissions](#hardware--permissions). A container shares the
host kernel and is isolated by design, so host hardware is exposed explicitly rather
than automatically. This is the standard way every hardware-using HA/Docker app works
(e.g. Frigate, Zigbee2MQTT, ESPHome).

**What if I want zero hardware configuration?**
Either install Grablo natively (the regular installer runs directly on the host with
full hardware access), or use the [Home Assistant add-on](https://github.com/grablo/grablo-hass-addons),
which declares devices in `config.yaml` so the Supervisor wires them up for you.

---

## License

This repository contains only distribution packaging (Dockerfile / compose). The
Grablo IoT Core software itself is under Grablo's proprietary license.
