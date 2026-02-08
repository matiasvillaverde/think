#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IMAGE_NAME="${OPENCLAW_TEST_IMAGE:-think-openclaw-gateway-test:latest}"
HOST_PORT="${OPENCLAW_TEST_PORT:-18789}"
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

# Create an isolated OpenClaw config dir so the gateway token is deterministic and not affected
# by any auto-generated config inside the container.
STATE_DIR="$(mktemp -d)"
cleanup_state() {
  rm -rf "${STATE_DIR}" >/dev/null 2>&1 || true
}
trap cleanup_state EXIT

mkdir -p "${STATE_DIR}"
cat > "${STATE_DIR}/openclaw.json" <<EOF
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
  -v "${STATE_DIR}:/root/.openclaw" \
  "${IMAGE_NAME}" \
  openclaw gateway run --allow-unconfigured --bind lan --port 18789 --auth token --token "${TOKEN}" --verbose)"
cleanup() {
  echo "==> Stopping container ${CID}"
  docker stop "${CID}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "==> Waiting for gateway HTTP surface..."
for i in {1..60}; do
  if curl -fsS "http://127.0.0.1:${HOST_PORT}/" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! curl -fsS "http://127.0.0.1:${HOST_PORT}/" >/dev/null 2>&1; then
  echo "Gateway did not become ready. Recent logs:" >&2
  docker logs --tail 200 "${CID}" >&2 || true
  exit 1
fi

echo "==> Running ViewModels acceptance test against gateway"
(
  cd "${ROOT_DIR}/ViewModels"
  OPENCLAW_TEST_WS_URL="ws://127.0.0.1:${HOST_PORT}" \
  OPENCLAW_TEST_TOKEN="${TOKEN}" \
  swift test --filter OpenClawGatewayIntegrationTests || {
    echo "==> Integration test failed; dumping gateway diagnostics..." >&2
    docker logs --tail 200 "${CID}" >&2 || true
    echo "==> Container env (OPENCLAW*)..." >&2
    docker exec "${CID}" /bin/bash -lc 'env | grep -E "^OPENCLAW" || true' >&2 || true
    echo "==> Possible config locations..." >&2
    docker exec "${CID}" /bin/bash -lc 'ls -la /root/.openclaw || true; ls -la /root/.config/openclaw || true; ls -la /root/.config || true' >&2 || true
    docker exec "${CID}" /bin/bash -lc 'for p in /root/.openclaw/openclaw.json /root/.config/openclaw/openclaw.json; do echo "--- $p"; cat "$p" 2>/dev/null || true; done' >&2 || true
    exit 1
  }
)
