# badgeware-backup

Simple scripts to back up and restore the flash contents of [Badgwa.re](https://badgewa.re/) badges.

## Supported Badges

All three boards use an **RP2350** with **16 MB flash** and share the same flash layout, so both scripts work identically across them.

| Badge | Display | Board flag |
|---|---|---|
| [Tufty 2350](https://shop.pimoroni.com/products/tufty-2350?variant=55811986194811) | 2.8" colour TFT | `tufty` *(default)* |
| [Blinky 2350](https://shop.pimoroni.com/products/blinky-2350?variant=55812537680251) | LED matrix | `blinky` |
| [Badger 2350](https://shop.pimoroni.com/products/badger-2350?variant=55801169707387) | 2.7" e-paper | `badger` |

# Requirements

- [picotool](https://github.com/raspberrypi/picotool) — must be on your `$PATH`
- **Or:** Docker (see [Docker usage](#docker) below — picotool is bundled in the image)

## BOOTSEL Mode

Both scripts require the badge to be in **BOOTSEL mode** before running:

> Hold **BOOT**, press **RESET**, release both. The badge mounts as a USB drive.

# Usage

## Backup

```sh
# Tufty (default) — timestamped UF2 saved to backups/
./scripts/backup-flash.sh

# Badger — timestamped UF2
./scripts/backup-flash.sh -b badger

# Blinky — custom filename
./scripts/backup-flash.sh -b blinky my-blinky-factory.uf2

# Any board — raw binary instead of UF2
./scripts/backup-flash.sh -b tufty -r factory.bin

# Save to a different directory
./scripts/backup-flash.sh -b badger -d /tmp
```

```
Usage: backup-flash.sh [OPTIONS] [FILENAME]

Options:
  -b BOARD    Target board: tufty | blinky | badger  (default: tufty)
  -r          Save as raw binary instead of UF2
  -d DIR      Backup directory                        (default: backups)
  -h          Show this help message
```

## Restore

```sh
# Restore a UF2 backup (board flag optional but recommended)
./scripts/restore-flash.sh -b tufty backups/tufty-backup-20250610-143022.uf2

# Restore a raw binary backup
./scripts/restore-flash.sh -b badger backups/badger-factory.bin

# List all available backups
./scripts/restore-flash.sh --list

# Restore without rebooting afterwards
./scripts/restore-flash.sh --no-reboot backups/tufty-backup-20250610-143022.uf2
```

```
Usage: restore-flash.sh [OPTIONS] BACKUP_FILE

Arguments:
  BACKUP_FILE     Path to .uf2 or .bin backup file

Options:
  -b BOARD        Target board: tufty | blinky | badger  (default: tufty)
  --list          List available backups in the backups/ directory
  --no-reboot     Do not reboot after flashing
  -h              Show this help message
```

## Backup directory

Backups are saved to `backups/` by default. This directory is tracked in git (via `.keep`) but its contents are gitignored — backup files will not be committed accidentally.

# Docker

A pre-built image is published to Docker Hub as [`frozenfoxx/badgeware-backup`](https://hub.docker.com/r/frozenfoxx/badgeware-backup). It bundles `picotool` so no local installation is needed.

The badge must still be in **BOOTSEL mode** before running any container command.

Because `picotool` communicates with the device over USB, the container needs access to the host USB subsystem (`--privileged` or a targeted `--device` bind).

```sh
# Backup — Tufty (default), UF2, saved to ./backups on the host
docker run --rm --privileged \
  -v "$(pwd)/backups:/backups" \
  frozenfoxx/badgeware-backup:latest \
  backup-flash.sh

# Backup — Badger, timestamped UF2
docker run --rm --privileged \
  -v "$(pwd)/backups:/backups" \
  frozenfoxx/badgeware-backup:latest \
  backup-flash.sh -b badger

# Restore a UF2 backup — Tufty
docker run --rm --privileged \
  -v "$(pwd)/backups:/backups" \
  frozenfoxx/badgeware-backup:latest \
  restore-flash.sh -b tufty /backups/tufty-backup-20250610-143022.uf2

# List available backups
docker run --rm \
  -v "$(pwd)/backups:/backups" \
  frozenfoxx/badgeware-backup:latest \
  restore-flash.sh --list

# Interactive shell (for debugging)
docker run --rm -it --privileged \
  -v "$(pwd)/backups:/backups" \
  frozenfoxx/badgeware-backup:latest
```

### Building the image locally

```sh
docker build -t badgeware-backup:latest .
```

### CI / Docker Hub

The image is built and pushed automatically via GitHub Actions on every push to `main` and on version tags (`v*`). Multi-platform builds (`linux/amd64` and `linux/arm64`) are produced using QEMU and Docker Buildx.
  
Two repository secrets are required in GitHub:

| Secret | Value |
|---|---|
| `DOCKER_HUB_USERNAME` | Your Docker Hub username |
| `DOCKER_HUB_ACCESS_TOKEN` | A Docker Hub access token with read/write scope |

## Contribution

Pull requests welcome.
