#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IMAGE_NAME="${OPENCLAW_TEST_IMAGE:-think-openclaw-gateway-test:latest}"
# Empirically, 18790->18789 is more reliable than 18789->18789 for auth + pairing.
HOST_PORT="${OPENCLAW_TEST_PORT:-18790}"
TOKEN="${OPENCLAW_TEST_TOKEN:-}"

if [[ -z "${TOKEN}" ]]; then
  if command -v openssl >/dev/null 2>&1; then
    TOKEN="$(openssl rand -hex 32)"
  else
    TOKEN="$(python3 - <<'PY'
import secrets
print(secrets.token_hex(32))
PY
)"
  fi
fi

STATE_DIR="$(mktemp -d)"
cleanup_state() {
  rm -rf "${STATE_DIR}" >/dev/null 2>&1 || true
}
trap cleanup_state EXIT

mkdir -p "${STATE_DIR}/openclaw-state"
cat > "${STATE_DIR}/openclaw-state/openclaw.json" <<EOF
{
  "gateway": {
    "mode": "local",
    "bind": "lan",
    "auth": { "mode": "token", "token": "${TOKEN}" }
  }
}
EOF

echo "==> Building test gateway image: ${IMAGE_NAME}"
docker build -t "${IMAGE_NAME}" -f "${ROOT_DIR}/scripts/openclaw-test/Dockerfile" "${ROOT_DIR}/scripts/openclaw-test" >/dev/null

echo "==> Starting OpenClaw gateway container (host port ${HOST_PORT})"
CID="$(docker run -d --rm \
  -p "${HOST_PORT}:18789" \
  -e "OPENCLAW_GATEWAY_TOKEN=${TOKEN}" \
  -v "${STATE_DIR}/openclaw-state:/root/.openclaw" \
  "${IMAGE_NAME}" \
  openclaw gateway --dev --force --bind lan --port 18789 --auth token --token "${TOKEN}" --verbose run)"
cleanup() {
  echo "==> Stopping container ${CID}"
  docker stop "${CID}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "==> Waiting for gateway to be ready..."
for _ in {1..60}; do
  if docker logs "${CID}" | grep -q "listening on ws://"; then
    break
  fi
  sleep 1
done
if ! docker logs "${CID}" | grep -q "listening on ws://"; then
  echo "Gateway did not become ready. Recent logs:" >&2
  docker logs --tail 200 "${CID}" >&2 || true
  exit 1
fi

sleep 15

echo "==> Running ThinkCLI acceptance test against gateway"
(
  cd "${ROOT_DIR}/ThinkCLI"
  OPENCLAW_ACCEPTANCE=1 \
  OPENCLAW_TEST_WS_URL="ws://127.0.0.1:${HOST_PORT}" \
  OPENCLAW_TEST_TOKEN="${TOKEN}" \
  make test
)

