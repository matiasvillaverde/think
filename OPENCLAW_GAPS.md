# OpenClaw Parity Tickets

This backlog maps remaining OpenClaw-style behaviors to concrete work items in this codebase.

| Ticket | Behavior | Current State | Next Step |
| --- | --- | --- | --- |
| OCW-001 | UI consumes gateway event stream for token streaming + tool progress | Adapter wired to update tool execution state/progress from `AgentEventStream` | ✅ Done |
| OCW-002 | Remote gateway service (HTTP/SSE/WebSocket) | `RemoteGatewayService` implemented with auth + tests | ✅ Done |
| OCW-003 | Plugin trust evaluation + user approval flow | Plugin manifest loader + approval UI + trust store wiring + tests | ✅ Done |
| OCW-004 | Signing key rotation updates | Trust store can hold keys, but no update mechanism | ✅ Done |
| OCW-005 | Enforced sandboxing for untrusted plugins/tools | `sandboxed` flag exists, no enforcement | ✅ Done |
