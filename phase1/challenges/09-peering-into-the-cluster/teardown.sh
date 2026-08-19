#!/usr/bin/env bash
source "$(git rev-parse --show-toplevel)/shared/lib/common.sh"
require kind
kind delete cluster --name cypher09 >/dev/null 2>&1 || true
echo "09 kind cluster deleted"
