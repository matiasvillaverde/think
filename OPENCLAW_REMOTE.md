# Remote OpenClaw Gateway

Think can connect to a remote OpenClaw Gateway instance over WebSocket.

This is intended for connecting your Think app (or ThinkCLI) to an OpenClaw gateway you run on another machine.

## Security Model (Current)

- Gateway instances (name + URL + active selection) are stored in **SwiftData**.
- Gateway secrets are stored in **Keychain** (not in SwiftData):
  - Shared gateway token (if you use token auth)
  - Device private key (Curve25519 signing key)
  - Device token (returned by the gateway after pairing)
- In non-Debug builds, Think prefers secure transport:
  - `wss://` is required for non-local hosts.
  - `ws://` is allowed only for `localhost`, `127.0.0.1`, and `::1`.

## Run a Gateway (Docker, for Testing)

This repo includes a docker harness that runs `openclaw gateway` and runs the ViewModels acceptance test against it:

```bash
bash scripts/openclaw-test/run.sh
```

That script:
- builds a docker image with `openclaw`
- starts the gateway on `ws://127.0.0.1:18790`
- runs `ViewModels/Tests/ViewModelsTests/OpenClawGatewayIntegrationTests.swift`

## Connect Using the App UI

1. Open Think.
2. Go to Settings.
3. Open the `OpenClaw` tab.
4. Add a new instance:
   - Name: anything
   - URL: your gateway WebSocket URL (`wss://...` recommended)
   - Token (optional): shared gateway token (stored in Keychain)
5. Select the instance as active.
6. Tap “Test Connection”.
   - If pairing is required, Think will show a `requestId`.
7. Approve pairing on the gateway side, then “Test Connection” again.

Once configured, the chat toolbar shows an OpenClaw status indicator. You can open “Manage Instances” from the chat screen.

## Connect Using ThinkCLI

Build and run ThinkCLI from the repo:

```bash
cd ThinkCLI
make run ARGS="openclaw list"
```

### Add an instance

```bash
cd ThinkCLI
make run ARGS="openclaw upsert --name \"My Gateway\" --url \"wss://gateway.example.com\" --token \"<shared-token>\" --activate"
```

### Test connection (expect pairing required the first time)

```bash
cd ThinkCLI
make run ARGS="openclaw test --id <instance-uuid>"
```

If you see:
- `Pairing required. requestId=...`

### Approve pairing

```bash
cd ThinkCLI
make run ARGS="openclaw approve-pairing --url \"wss://gateway.example.com\" --token \"<shared-token>\" --request-id \"<requestId>\""
```

### Test again (expect connected)

```bash
cd ThinkCLI
make run ARGS="openclaw test --id <instance-uuid>"
```

### Delete instance

```bash
cd ThinkCLI
make run ARGS="openclaw delete --id <instance-uuid>"
```

## Automated CLI Smoke Test (Real Gateway)

There is a shell smoke test that starts a real gateway in Docker and drives ThinkCLI through:
- upsert
- test (pairing required)
- approve pairing
- test (connected)
- delete

```bash
bash scripts/openclaw-test/cli-smoke.sh
```

## Automated CLI Acceptance Test (SwiftTesting + Real Gateway)

There is also an opt-in SwiftTesting suite that runs inside `ThinkCLI` tests and connects to a real gateway.

This script starts a gateway in Docker and runs `ThinkCLI` tests with the required env vars enabled:

```bash
bash scripts/openclaw-test/cli-acceptance.sh
```
