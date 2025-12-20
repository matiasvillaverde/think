# Repository Guidelines

## Before You Start
- Read `CLAUDE.md` (root + modules). Use Make only: `make lint` → `make build` → `make test` → `make run`. Do not run from Xcode. For App Store flows, copy `scripts/.env.example` → `scripts/.env`.

## Project Structure
- Modules at repo root: `Abstractions/`, `AgentOrchestrator/`, `ViewModels/`, `UIComponents/`, `Database/`, `MLXSession/`, `LLamaCPP/`, `ImageGenerator/`, `AudioGenerator/`, `ModelDownloader/`, `RAG/`, `Factories/`, `Tools/`. Apps: `Think/`, `Think Vision/`. Tests in `Module/Tests/`.

## Module Architecture
- Contracts live in `Abstractions/` (protocols, models, errors). Most packages must compile against these only.
- Data lives in `Database/`. High‑level modules (e.g., `ViewModels/`, `UIComponents/`, `Tools/`) may import `Database` when they truly need persistence APIs.
- Backends (`ImageGenerator/`, `MLXSession/`, `LLamaCPP/`, `ModelDownloader/`) depend only on `Abstractions` and expose protocol‑conforming types.
- Composition happens in `Factories/`: constructs concrete implementations and injects them where needed. Do not create cross‑package singletons.
- `AgentOrchestrator/` coordinates backends via `Abstractions` protocols; add/replace implementations through DI, not direct new calls in consumers.

## Architecture Diagram
```
     +------+                 +------+        
     |Apps  |                 |Tools |        
     +--+---+                 +--+---+        
        |                        |           
  +-----v------+          +------v-----+      
  | UI + VMs   |          |   RAG      |      
  +-----+------+          +------+-----+      
        |      composition via Factories      
        |              |                      
  +-----v--------------v----+                 
  |         Orch (DI)       |                 
  +-----+-------------------+                 
        |                                     
   +----v----+      +--------------+          
   |  Ctx    |      | Bknds (MLX/ |--> IMG/LLM
   +----+----+      |    LLM/IMG) |          
        |           +------+-------+          
        |                  |                  
        |            +-----v----+             
        |            |   MDL    |             
        |            +-----+----+             
        |                  |                  
  +-----v------------------v----+             
  |            DB (SwiftData)   |             
  +-----------------------------+             
```

## Build, Test, and Development
- `make setup`, `make lint`, `make test[-all]`, `make build[-all]`, `make run`. PRs: `make review-pr PR=123`.

Example: run per-module: `cd ViewModels && make lint && make test && make build`.

## Coding Style
- Swift 6 + SwiftUI; strict SwiftLint (run before commits). Use defaults; justify any disables. Branch naming: `feat/<name>`, `fix/<name>`.

## Testing Guidelines
- Use SwiftTesting; keep tests deterministic and mocked. Run `make test` per module, `make test-all` repo-wide. Acceptance (as needed): `cd ImageGenerator && make test-acceptance`, `cd ModelDownloader && make test-acceptance`, `cd Database && make test-acceptance`.

## Commits & Pull Requests
- Conventional Commits (examples): `feat: add RAG search`, `fix(database): handle migration`, `feat!: migrate to SwiftData 2.0`.
- PRs include description, linked issues, and UI screenshots when relevant; ensure `make review-pr` passes.

## Security & Config
- Never commit secrets. Use `scripts/.env`; keep `private_keys/` local. Verify with `make check-env` for App Store workflows.
