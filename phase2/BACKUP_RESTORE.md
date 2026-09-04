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

**Reboot-tested, not just configured.** Actually reset `cypher-phase2`
(`gcloud compute instances reset cypher-phase2 --zone=asia-south1-a --project=cypher-p1`)
and confirmed live: SSH back in ~20s, Docker active, all 10 containers back up on their
own within 15s, `cypher-metadata-block.service` reapplied the rule, and all endpoints
verified reachable again externally. The auto-start story above is proven, not assumed.

## Monitoring & DoS protection (2026-09-04)

**Firewall visibility**: rule logging is on for every participant-facing and admin
firewall rule (`cypher-allow-web`, `cypher-allow-challenges`, `cypher-allow-whale`,
`cypher-allow-ssh-admin`, `cypher-allow-ssh-iap`). VPC Flow Logs are on for
`cypher-subnet` (50% sampling, 5s aggregation). Both land in Cloud Logging —
`gcloud logging read "resource.type=gce_subnetwork" --project=cypher-p1 --limit=50`
for flow logs, or filter on `jsonPayload.connection` for firewall hits.

**Alerting**: two Cloud Monitoring policies, emailing `suresh@gdgsrilanka.org`, watching
`cypher-phase2`/`cypher-h01`/`cypher-i01`:
- CPU > 85% sustained 5 minutes ("Phase2 - High CPU (possible DoS/abuse)")
- Inbound traffic spike, sustained 3 minutes ("Phase2 - Abnormal inbound traffic
  (possible flood)")

Check firing/history: `gcloud alpha monitoring policies list --project=cypher-p1`.

**Active rate limiting**: per-source-IP connection-rate limit on the challenge ports of
all three internet-facing VMs, via a systemd-persisted iptables rule (same pattern as
the metadata-block rule):
```
/etc/systemd/system/cypher-ratelimit.service
```
Drops **new** TCP connections from a single source IP once it exceeds **50/sec (burst
100)** on `cypher-phase2:8000-8099` and `cypher-h01`/`cypher-i01:8001`. This assumes
**each team has a distinct public IP at the venue** — if that's not true on the day
(everyone behind one shared NAT), this would rate-limit the whole room as one source and
should be disabled instead:
```sh
gcloud compute ssh <vm> --zone=asia-south1-a --project=cypher-p1 --tunnel-through-iap \
  --command="sudo systemctl disable --now cypher-ratelimit.service; sudo iptables -D DOCKER-USER -p tcp --dport <port> -m conntrack --ctstate NEW -m hashlimit --hashlimit-name cypher_dos --hashlimit-mode srcip --hashlimit-above 50/sec --hashlimit-burst 100 -j DROP"
```
Threshold was chosen with real headroom over legitimate use and live-tested twice on
`cypher-phase2`:
- **Quick burst**: 30 rapid sequential requests all passed clean; a 250-connection
  parallel burst got ~35% dropped (rule engaging correctly) while the rest still got
  through; service recovered within seconds.
- **Sustained 45s flood** (continuous 40-way parallel requests against h08, single
  source IP): drop counter climbed from 227 to 603+ packets during the flood, host load
  average stayed at **0.00** the entire time (8-vCPU box never noticed), every *other*
  container stayed under 0.1% CPU, and h08 itself — the actual target — stayed at ~2%
  CPU and kept answering individual legitimate probes with 200 throughout. The flooding
  IP (mine) then hit a several-second cooldown lockout immediately after the flood
  ended — the rule tracks sustained abuse, not just instantaneous bursts, so a real
  single-IP flood gets *increasingly* penalized the longer it persists. Full recovery
  confirmed within under a minute; zero impact on any other container or on `h01`/`i01`,
  which weren't targeted.

Net: the per-container resource limits (`SECURITY.md` §1) and this connection cap
combine to make a single-source flood a non-event for the other nine teams — verified,
not assumed. What's still untested: a distributed flood from many source IPs at once
(the rate limit is per-source-IP by design, so it doesn't defend against that shape of
attack — only the per-container resource caps would, by starving each individual
connection's container of CPU rather than blocking the connection itself).

## Backups (GCE machine images)

A machine image is a point-in-time snapshot of the **entire VM** (boot disk + config) —
one command recreates a fully working instance from it, no manual disk-swapping.

| VM | Current machine image | Taken | Superseded |
|---|---|---|---|
| `cypher-phase2` | `cypher-phase2-bak-20260904b` | 2026-09-04, post-hardening | `cypher-phase2-bak-20260904` (pre monitoring/rate-limit) |
| `cypher-h01` | `cypher-h01-bak-20260904b` | 2026-09-04, post-hardening | `cypher-h01-bak-20260904` |
| `cypher-i01` | `cypher-i01-bak-20260904b` | 2026-09-04, post-hardening | `cypher-i01-bak-20260904` |
| `cypher-platform` | `cypher-platform-bak-20260904` | 2026-09-04 ~20:45 SLT | (unchanged since) |

Use the `b` images for restores — they include the metadata block, static IPs already
being moot (address is separate from the image), and the rate-limit/monitoring setup
from this section. The pre-hardening images are kept only as a fallback, not preferred.

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
  --source-machine-image=<vm-name>-bak-20260904b \
  --zone=asia-south1-a --address=<vm-name>-ip --project=cypher-p1
```
Substitute the VM name (`cypher-phase2` / `cypher-h01` / `cypher-i01`; use
`cypher-platform-bak-20260904`, no `b` suffix, for that one) in all three places. After
it boots, confirm services are back:
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
