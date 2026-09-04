# Phase 2 finals — backup & restore (admin)

Disaster-recovery reference for the four finals VMs. Read this if something goes down
during the event and you need it back **fast**.

## What's already true (no action needed)

- **Docker starts on boot** on all four VMs (`systemctl is-enabled docker` → `enabled`).
- Every challenge container runs with **`--restart unless-stopped`**, so once Docker is
  up, all containers come back automatically — no manual redeploy after a reboot.
- The `phase2/whale/docker-compose.yml` platform stack (CTFd/db/cache/frps/proxy), once
  brought up, has `restart: unless-stopped` on every service too — same guarantee.

## What was fixed (2026-09-04)

The metadata-egress-block iptables rule on `cypher-phase2` (blocks challenge containers
from reaching the GCE metadata server — critical for the h06/h08/i04-class RCE
challenges per `SECURITY.md` §2/§3) was **in-memory only** and would have silently
vanished on reboot. Fixed with a systemd unit:

```
/etc/systemd/system/cypher-metadata-block.service   # on cypher-phase2
```

Reapplies `iptables -I DOCKER-USER -d 169.254.169.254 -p tcp --dport 80 -j DROP` after
`docker.service` on every boot. Enabled (`systemctl enable`), verified active. Check it
survived a reboot with:
```sh
gcloud compute ssh cypher-phase2 --zone=asia-south1-a --project=cypher-p1 --tunnel-through-iap \
  --command="systemctl is-active cypher-metadata-block.service; sudo iptables -L DOCKER-USER -n"
```

All four VMs also got a **static external IP** (previously ephemeral) so a restored VM
keeps the exact address every `connection_info` / `SOLUTIONS.md` entry already points at:

| VM | Static IP | Reserved address name |
|---|---|---|
| `cypher-phase2` (challenge containers) | `34.14.164.225` | `cypher-phase2-ip` |
| `cypher-h01` (Token Relay SSRF) | `34.93.227.142` | `cypher-h01-ip` |
| `cypher-i01` (Metadata Skim SSRF) | `34.47.134.78` | `cypher-i01-ip` |
| `cypher-platform` (CTFd, via Cloudflare Tunnel) | `8.231.71.161` | `cypher-platform-ip` |

## Backups (GCE machine images)

A machine image is a point-in-time snapshot of the **entire VM** (boot disk + config) —
one command recreates a fully working instance from it, no manual disk-swapping.

| VM | Machine image | Taken |
|---|---|---|
| `cypher-phase2` | `cypher-phase2-bak-20260904` | 2026-09-04 ~20:45 SLT |
| `cypher-h01` | `cypher-h01-bak-20260904` | 2026-09-04 ~20:45 SLT |
| `cypher-i01` | `cypher-i01-bak-20260904` | 2026-09-04 ~20:45 SLT |
| `cypher-platform` | `cypher-platform-bak-20260904` | 2026-09-04 ~20:45 SLT |

```sh
gcloud compute machine-images list --project=cypher-p1
```

> ⚠️ **These are frozen at the timestamp above.** If challenges get reloaded, CTFd gets
> configured, or anything else changes on these VMs before/during the event, the backups
> won't reflect it. Re-take them (same commands, a new date-suffixed name) after any
> further change — cheap and non-disruptive, takes under a minute per VM:
> ```sh
> gcloud compute machine-images create cypher-phase2-bak-$(date +%Y%m%d) \
>   --source-instance=cypher-phase2 --source-instance-zone=asia-south1-a --project=cypher-p1
> # repeat for cypher-h01 / cypher-i01 / cypher-platform
> ```

## Restore procedure — fastest path first

**1. Transient issue (hung, OOM, unresponsive, weird state) — try this first.**
Keeps the disk and the IP; Docker + `restart: unless-stopped` bring everything back with
zero manual steps, usually within a minute or two of the VM coming back up:
```sh
gcloud compute instances reset <vm-name> --zone=asia-south1-a --project=cypher-p1
```

**2. VM destroyed, corrupted, or reset didn't help — restore from the backup.**
Reuses the same static IP, so nothing downstream (CTFd `connection_info`,
`SOLUTIONS.md`, anything a team already saved) needs to change:
```sh
# only if the broken instance still exists:
gcloud compute instances delete <vm-name> --zone=asia-south1-a --project=cypher-p1 --quiet

gcloud compute instances create <vm-name> \
  --source-machine-image=<vm-name>-bak-20260904 \
  --zone=asia-south1-a --address=<vm-name>-ip --project=cypher-p1
```
Substitute the VM name (`cypher-phase2` / `cypher-h01` / `cypher-i01` / `cypher-platform`)
in all three places. After it boots, confirm services are back:
```sh
curl -s -o /dev/null -w '%{http_code}\n' http://<static-ip>:<port>/   # per phase2/SOLUTIONS.md's endpoint table
```

**3. Sanity-check after ANY restore of `cypher-phase2`** — confirm the metadata block
came back (see the command under "What was fixed" above) before opening the board back
up; a fresh VM from an *older* machine image (predating the fix) won't have the systemd
unit and would need it reapplied.

## Quick reference — what's where

| VM | Role | Containers / what runs there |
|---|---|---|
| `cypher-phase2` | Shared challenge containers | e02, i02, m03, h06, h08, h10, i04, ai1, ai2, ai3 |
| `cypher-h01` | Dedicated SSRF VM | Token Relay app (`h01app`, scoped SA `webhook-runner@`) |
| `cypher-i01` | Dedicated SSRF VM | Metadata Skim app (`i01app`, scoped SA `aperide-preview@`) |
| `cypher-platform` | CTFd platform | `platform-ctfd-1`, `platform-db-1`, `platform-cache-1`, `platform-cloudflared-1` |

Cloud-only challenges (e01, m01, h05, h02) and static attachments (h12, h14, h15, i03)
have no VM to restore — see `phase2/SOLUTIONS.md` for their live GCP resources, which are
independent of any of the four VMs above.
