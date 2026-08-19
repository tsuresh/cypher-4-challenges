#!/usr/bin/env bash
# gcp/vm-startup.sh — GCE startup-script. Runs on first boot as root.
# Installs Docker Engine + Compose plugin and prepares the host for CTFd.
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

# kind + kubectl for challenge 09 (local cluster, no GKE)
curl -fsSLo /usr/local/bin/kind https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64
chmod +x /usr/local/bin/kind
curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/v1.30.0/bin/linux/amd64/kubectl"
chmod +x /usr/local/bin/kubectl

# Host-level firewall belt-and-braces (VPC firewall is primary)
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 10000:10100/tcp
ufw --force enable

mkdir -p /opt/cypher
echo "startup-complete $(date -u +%FT%TZ)" > /opt/cypher/.startup-done
