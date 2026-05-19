---
name: scaffold-new-sdk
description: Bootstrap a brand-new language Tx3 SDK folder (e.g. python-sdk, go-sdk, swift-sdk) seeded from sdks/sdk-spec/. Use when starting a new SDK from scratch.
---

# scaffold-new-sdk

Lay down a new `<lang>-sdk/` folder with the idiomatic project skeleton, TRP client stub, facade stub, and a seeded column in the parity matrix.

## When to use

- "Start a Python SDK."
- "We need a Go SDK scaffold so a contributor can pick it up."
- "Create a Swift SDK skeleton from the spec."
- Not for adding features to an existing SDK — that's `add-sdk-feature`.

## Inputs

From the user (ask if missing):
- **Target language** (e.g. Python, Go, Swift, Kotlin).
- **Package / crate name** (default: `tx3-sdk` or `tx3_sdk` per language convention).
- **Folder name** (default: `<lang>-sdk`, matching `rust-sdk` / `web-sdk`).
- **Build tooling preference**, if strong (e.g. `uv` vs `poetry`, `go mod`, `SwiftPM`).

## Procedure

1. **Read the spec.** `sdks/sdk-spec/api-surface/` is your checklist: every MUST becomes a stub in the scaffold.
2. **Research the target language's conventions** — quickly. You only need enough to pick:
   - Project root layout (src layout, module layout, workspace layout).
   - Package manifest file (`pyproject.toml`, `go.mod`, `Package.swift`, etc.).
   - Test framework (pytest, go test, XCTest).
   - Linter / formatter (ruff, gofmt, swiftformat).
   - Async model (asyncio, goroutines, async/await).
3. **Create the folder skeleton.** At minimum:
   ```
   <lang>-sdk/
   ├── README.md              # Quick start, copied/adapted from rust-sdk/README.md
   ├── <manifest>             # e.g. pyproject.toml, go.mod, Package.swift
   ├── .gitignore
   ├── LICENSE                # Apache-2.0 (match rust-sdk / web-sdk)
   ├── src/ (or pkg/, Sources/)
   │   ├── <entry point>      # Re-exports per spec §4
   │   ├── trp/               # Low-level TRP client (§3.2)
   │   ├── tii/               # Protocol loader (§3.1)
   │   ├── facade/            # Tx3Client + builder chain (§3.3)
   │   └── signer/            # Signer interface + CardanoSigner + Ed25519Signer (§3.5)
    ├── tests/                 # End-to-end tests + shared fixtures (unit tests may be co-located)
   └── examples/              # Copy transfer.tx3 + transfer.tii from rust-sdk
   ```
   Folder names follow the target language's conventions — the layout above is semantic, not literal.
4. **Stub every §3 capability.** Each stub:
   - Has the canonical name from the glossary, translated to the language's casing.
   - Has a docstring matching the spec subsection verbatim (paraphrase the rationale, quote the MUST requirements).
   - Throws / returns a `NotImplementedError` equivalent.
    - Has unit coverage in the language-idiomatic location (co-located or `tests/`) and is marked skipped (`pytest.skip`, `t.Skip(...)`, etc.) until implemented.
5. **Copy the TII example.** Put `rust-sdk/examples/transfer.tii` and `transfer.tx3` under the new SDK's `examples/` so the very first test target is "load this file with `Protocol.fromFile` and assert it parses".
6. **Add an `AGENTS.md` entry.** Edit the inventory table in `/AGENTS.md` to include the new SDK row (version 0.0.0, "skeleton").
7. **Seed the parity matrix.** Add a column for the new SDK in `sdks/parity-matrix.md`. All cells start as ❌ except §3.1 (the TII example should at minimum be parseable once the stub is filled in). Add a per-SDK summary section describing the state and the recommended implementation order (3.2 TRP → 3.1 TII → 3.5 signers → 3.3 facade → 3.7 wait modes).
8. **Minimal CI placeholder.** Create `.github/workflows/` with a single workflow that just runs the target language's standard test command. Don't overthink it; this is a placeholder, not a release pipeline.
9. **Report:**
   - Folder created, file tree summary.
   - Package manifest contents (short).
   - Exactly which §3 capabilities are stubbed vs absent.
   - Recommended next steps (usually: "implement `TRPClient.resolve` first, wire it up against an example TRP endpoint").

## Guardrails

- **Don't ship implementations disguised as stubs.** A stub is a named symbol with a docstring and a `NotImplementedError`. If you start writing real logic, stop and route the work through `add-sdk-feature` instead.
- **Match the target language's norms, not the reference SDK's.** If Python convention is `snake_case` with `async def`, use that. The Rust SDK's Arc-based builder doesn't belong in Python.
- **Don't add dependencies beyond HTTP + JSON + crypto primitives.** Keep the scaffold boring. Dependency choices are the contributor's call.
- **Never copy-paste `.tx3` compilation logic.** SDKs consume `.tii`; compilation is the Tx3 toolchain's job.
- **Ask before picking contentious tooling.** Python (uv vs poetry vs hatch), JS (npm vs pnpm), JVM (gradle vs maven) — don't decide silently.

## Example flow

> User: scaffold a Python SDK under `python-sdk/`.
>
> 1. Read spec §3.
> 2. Conventions: src layout, `pyproject.toml` with `uv`, pytest, ruff, asyncio.
> 3. Create `python-sdk/` with `src/tx3_sdk/{trp,tii,facade,signer}/__init__.py`, each stubbed.
> 4. Copy `transfer.tii` + `transfer.tx3` to `python-sdk/examples/`.
> 5. Add `python-sdk` row to `/AGENTS.md` inventory.
> 6. Add `python-sdk` column to `sdks/parity-matrix.md`, seed ❌.
> 7. Add GH workflow running `uv run pytest`.
> 8. Report: skeleton ready, 0/9 §3 capabilities implemented, next step is `TRPClient.resolve`.
