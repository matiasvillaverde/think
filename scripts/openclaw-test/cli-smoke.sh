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

# The gateway can accept connections slightly before auth and subsystems settle.
sleep 15

WS_URL="ws://127.0.0.1:${HOST_PORT}"

echo "==> Building ThinkCLI"
(
  cd "${ROOT_DIR}/ThinkCLI"
  swift build --configuration debug >/dev/null
)
THINK_BIN="$(cd "${ROOT_DIR}/ThinkCLI" && swift build --configuration debug --show-bin-path)/think"

echo "==> Creating OpenClaw instance via ThinkCLI"
UPSERT_OUT="$("${THINK_BIN}" openclaw upsert --name "Local Gateway" --url "${WS_URL}" --token "${TOKEN}" --activate)"
echo "${UPSERT_OUT}"

INSTANCE_ID="$(
  echo "${UPSERT_OUT}" | tr -d '\r' | grep -Eo '[0-9A-Fa-f-]{36}' | head -n 1 || true
)"
if [[ -z "${INSTANCE_ID}" ]]; then
  echo "Failed to locate instance id from 'think openclaw upsert' output" >&2
  exit 1
fi
echo "==> Active instance id: ${INSTANCE_ID}"

echo "==> Listing instances (debug)"
"${THINK_BIN}" openclaw list

echo "==> Testing connectivity (expect pairing required)"
TEST1_OUT="$("${THINK_BIN}" openclaw test --id "${INSTANCE_ID}")"
echo "${TEST1_OUT}"
REQUEST_ID="$(
  echo "${TEST1_OUT}" | tr -d '\r' | grep -Eo 'requestId=[0-9A-Fa-f-]{36}' | head -n 1 | cut -d= -f2 || true
)"
if [[ -z "${REQUEST_ID}" ]]; then
  echo "Expected a pairing requestId from 'think openclaw test', got none" >&2
  exit 1
fi
echo "==> Pairing requestId: ${REQUEST_ID}"

echo "==> Approving pairing via ThinkCLI (gateway RPC)"
"${THINK_BIN}" openclaw approve-pairing --url "${WS_URL}" --token "${TOKEN}" --request-id "${REQUEST_ID}"

echo "==> Testing connectivity again (expect connected)"
TEST2_OUT="$("${THINK_BIN}" openclaw test --id "${INSTANCE_ID}")"
echo "${TEST2_OUT}"
echo "${TEST2_OUT}" | grep -q "Connected\\." || {
  echo "Expected connected status after pairing approval" >&2
  exit 1
}

echo "==> Cleaning up instance (also removes OpenClaw secrets from Keychain)"
"${THINK_BIN}" openclaw delete --id "${INSTANCE_ID}"

echo "==> CLI smoke test complete."
