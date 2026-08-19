#!/usr/bin/env bash
# phase1/test-local.sh — build & run the container-backed challenges on your
# LOCAL Docker (no GCP, no CTFd), then smoke-test each solve path. For dev
# iteration only; the real event uses provision.sh on the VM.
#
#   ./phase1/test-local.sh up      # build + run 02,03,05,08 on 180xx ports, test them
#   ./phase1/test-local.sh down     # stop & remove the local test containers
#
# Locally testable:      02, 03, 05 (web), 08 (DinD, needs privileged)
# Runs but no flag path: 04 (SSRF app runs; 169.254.169.254 only exists on GCE)
# NOT local (need GCP):  01, 06, 07, 10, 11        NOT here (kind): 09
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/shared/lib/common.sh"
require docker curl
FLAG="${TEST_FLAG:-CYPHER{local_test_$(date +%s)}}"
CH="$REPO_ROOT/phase1/challenges"

down() {
  docker rm -f cy-t02 cy-t03 cy-t05 cy-t08 cy-t08-inner cy-t04 >/dev/null 2>&1 || true
  ok "local test containers removed"
}

up() {
  step "building images (first run pulls base images — be patient)"
  docker build -q -t cy/02 "$CH/02-leaked-ledger"    >/dev/null
  docker build -q -t cy/03 "$CH/03-forgotten-backup" >/dev/null
  docker build -q -t cy/05 "$CH/05-git-happens"      >/dev/null
  docker build -q -t cy/04 "$CH/04-metadata-mischief" >/dev/null

  step "running on localhost:180xx  (flag=$FLAG)"
  down
  docker run -d --name cy-t02 -e CHAL_FLAG="$FLAG" -p 18002:80   cy/02 >/dev/null
  docker run -d --name cy-t03 -e CHAL_FLAG="$FLAG" -p 18003:80   cy/03 >/dev/null
  docker run -d --name cy-t05 -e CHAL_FLAG="$FLAG" -p 18005:80   cy/05 >/dev/null
  docker run -d --name cy-t04 -p 18004:8000 cy/04 >/dev/null
  # 08: DinD sandbox + inner flag container
  docker run -d --name cy-t08 --privileged -e DOCKER_TLS_CERTDIR= -p 18008:2375 \
    docker:26-dind dockerd --host=tcp://0.0.0.0:2375 >/dev/null 2>&1 || warn "08 DinD may need privileged; skipping"
  sleep 5
  if DOCKER_HOST=tcp://localhost:18008 docker info >/dev/null 2>&1; then
    DOCKER_HOST=tcp://localhost:18008 docker run -d --name ceylon-inventory \
      -e FLAG="$FLAG" alpine:3.20 sleep infinity >/dev/null 2>&1 || true
  fi

  step "smoke tests"
  local ok_all=1
  grep -q "$FLAG" <(curl -fsS http://localhost:18002/.env 2>/dev/null)                 && ok "02 /.env leaks flag"        || { err "02 FAIL"; ok_all=0; }
  grep -q "$FLAG" <(curl -fsS http://localhost:18003/backups/db_backup.sql 2>/dev/null) && ok "03 backup leaks flag"       || { err "03 FAIL"; ok_all=0; }
  [[ "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:18005/.git/HEAD)" == 200 ]] \
     && [[ "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:18005/config.php)" == 404 ]] \
     && ok "05 .git served, secret only in history" || { err "05 FAIL"; ok_all=0; }
  [[ "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:18004/healthz)" == 200 ]] \
     && ok "04 SSRF app up (metadata target only exists on GCE)" || warn "04 app not responding"
  if DOCKER_HOST=tcp://localhost:18008 docker ps >/dev/null 2>&1; then
    grep -q "$FLAG" <(curl -fsS http://localhost:18008/containers/ceylon-inventory/json 2>/dev/null) \
      && ok "08 Docker API exposes inner container env flag" || warn "08 inner container not ready"
  else
    warn "08 DinD API not reachable locally (privileged containers may be restricted)"
  fi
  echo
  [[ $ok_all -eq 1 ]] && ok "local web challenges PASS" || die "some checks failed"
  cat <<EOF

  Try them in a browser:
    02  http://localhost:18002/.env
    03  http://localhost:18003/backups/db_backup.sql
    04  http://localhost:18004/          (SSRF app UI)
    05  http://localhost:18005/.git/     (git-dumper http://localhost:18005/.git/ loot; cd loot; git log -p)
    08  DOCKER_HOST=tcp://localhost:18008 docker ps
  Tear down:  ./phase1/test-local.sh down
EOF
}

case "${1:-up}" in
  up)   up ;;
  down) down ;;
  *)    die "usage: $0 [up|down]" ;;
esac
