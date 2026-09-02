# borg-ssh-container

A minimal Docker container that exposes an SSH server for use as a [BorgBackup](https://www.borgbackup.org/) remote repository. It's meant to run on a backup destination host so that clients can `borg` push/pull over SSH using key-based authentication.

## What's inside

- Ubuntu 26.04 base image
- `openssh-server` and `borgbackup` installed via apt
- A dedicated, unprivileged `borg` user (home: `/home/borg`)
- SSH hardened out of the box:
  - Password authentication disabled (key-only)
  - Root login disabled
- SSH host keys persisted outside the default location (`/etc/ssh/host_keys`) so they can be mounted from a volume and stay stable across container recreations
- Host keys are auto-generated on first start if missing (`start-sshd.sh`)

## Image

Prebuilt images are published to GitHub Container Registry:

```
ghcr.io/oliviakrkk/borg-backup-receiver:latest
```

The image is built for `linux/arm64` and rebuilt automatically every week (see [Automated builds](#automated-builds)).

## Usage

### 1. Provide an SSH public key for the `borg` user

Since password auth is disabled, you need to supply an `authorized_keys` file for the `borg` user, e.g. by mounting it in:

```bash
docker run -d \
  --name borg-backup-receiver \
  -p 2222:22 \
  -v ./authorized_keys:/home/borg/.ssh/authorized_keys:ro \
  -v borg-host-keys:/etc/ssh/host_keys \
  -v borg-data:/home/borg/backups \
  ghcr.io/oliviakrkk/borg-backup-receiver:latest
```

- `authorized_keys` should contain the public key(s) of the clients allowed to connect as `borg`.
- Mounting `/etc/ssh/host_keys` as a named volume keeps the server's host key identity stable across container restarts/recreations, avoiding SSH "host key changed" warnings on clients.
- Mount a data volume for wherever you want borg repositories stored (e.g. `/home/borg/backups`).

### 2. Point Borg clients at it

From a client machine:

```bash
borg init --encryption=repokey ssh://borg@<host>:2222/home/borg/backups/myrepo
borg create ssh://borg@<host>:2222/home/borg/backups/myrepo::{now} /path/to/data
```

### Docker Compose example

```yaml
services:
  borg-backup-receiver:
    image: ghcr.io/oliviakrkk/borg-backup-receiver:latest
    container_name: borg-backup-receiver
    restart: unless-stopped
    ports:
      - "2222:22"
    volumes:
      - ./authorized_keys:/home/borg/.ssh/authorized_keys:ro
      - borg-host-keys:/etc/ssh/host_keys
      - borg-data:/home/borg/backups

volumes:
  borg-host-keys:
  borg-data:
```

## Building locally

```bash
docker build -t borg-ssh-container .
```

## Automated builds

- **`.github/workflows/docker-weekly.yml`** — builds and pushes the `linux/arm64` image to GHCR every Monday at 03:00 UTC (and on manual dispatch).
- **`.github/workflows/dependabot-auto-merge.yml`** — auto-approves and merges Dependabot pull requests.
- **`.github/dependabot.yml`** — checks for updates to the base image and GitHub Actions monthly.

## Security notes

- Password authentication and root login are disabled by default — access is key-only via the `borg` user.
- Consider further restricting the `borg` user's SSH access with `command="borg serve ..."` and/or `restrict` in `authorized_keys` to limit it to Borg operations only.
- Keep the published image's base OS and dependencies up to date via the automated Dependabot/build workflows above.
