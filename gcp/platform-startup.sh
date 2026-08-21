#!/usr/bin/env bash
# gcp/platform-startup.sh — GCE startup-script for cypher-platform (CTFd host).
#
# Deliberately NOT gcp/vm-startup.sh: this host runs no challenges, so it gets
# no kind, no kubectl, and no 8000-8099 firewall opening. It has no ingress
# firewall rule at all — CTFd is reached only via the outbound Cloudflare
# tunnel, and administrative SSH arrives through IAP.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y ca-certificates curl gnupg git jq ufw

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker

# Host firewall: SSH only (from the IAP range; the VPC rule is primary).
# No web ports — nothing here is served publicly.
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw --force enable

mkdir -p /opt/cypher
echo "platform-startup-complete $(date -u +%FT%TZ)" > /opt/cypher/.startup-done
