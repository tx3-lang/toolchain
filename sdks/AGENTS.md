# Tx3 SDK fleet — agent guide

`sdks/` groups the fleet of Tx3 SDKs (one per language) plus the cross-cutting
artifacts that keep them consistent. It is part of the `lang-factory` meta-repo —
read the parent `lang-factory/AGENTS.md` first for what Tx3 is and how the toolkit
fits together; **this file overrides it for any work under `sdks/`**.

An **SDK** here is the language-specific client that loads `.tii` artifacts, binds
parties and signers, and drives the transaction lifecycle over the Transaction
Resolve Protocol (TRP). The SDKs are downstream of `tx3`/`trix`/`tii`: for
cross-cutting changes, bump them after the upstream change lands (treat like
`registry/`/`docs/`).

After this file, read `sdks/sdk-spec/README.md`, then the skill matching the task.

---

## SDK inventory

| Folder          | Language        | Package                          | Version | Notes                                                       |
|-----------------|-----------------|----------------------------------|---------|-------------------------------------------------------------|
| `rust-sdk/`     | Rust            | `tx3-sdk`                        | 0.11.0  | Reference implementation. Full facade + signers + poll loop.|
| `web-sdk/`      | TypeScript / JS | `tx3-sdk` (npm)                  | 0.11.0  | Runtime SDK with full §3 surface + build-time integrations. |
| `go-sdk/`       | Go              | `github.com/tx3-lang/go-sdk/sdk` | 0.11.0  | Idiomatic Go SDK with full §3 capability coverage.          |
| `python-sdk/`   | Python          | `tx3-sdk` (PyPI)                 | 0.11.0  | Async runtime SDK aligned with `sdks/sdk-spec/`.             |

Rust remains the reference implementation; all four track the same required §3
capability set. See `sdks/parity-matrix.md` for the live snapshot.

---

## Golden rules

1. **Idiomatic first.** Never port a Rust pattern verbatim into TypeScript, or vice
   versa. Builder chains, error types, async models, naming, and module layout must
   match the target language's community norms. The spec tells you *what* must
   exist, not *how*.
2. **Feature parity is the goal, surface shape is not.** If `sdks/sdk-spec/` says an
   SDK MUST support "wait for confirmed", every SDK exposes that capability — Rust
   as `wait_for_confirmed(PollConfig)`, TS as `await tx.waitForConfirmed({…})`.
3. **Any user-visible change in one SDK triggers a parity check against the
   others.** Make the matching change everywhere or explicitly log the gap in
   `sdks/parity-matrix.md`.
4. **Shared vocabulary lives in the spec — don't invent synonyms.**
   `sdks/sdk-spec/glossary.md` is authoritative. `Party`, `Signer`, `Profile`,
   `Invocation`, `resolve`, `submit`, `waitForConfirmed`, `waitForFinalized`,
   `TRP`, `TII`, `Protocol`, `TxBuilder` appear in every SDK, translated only for
   casing.
5. **When reviewing a PR in a single SDK, always flag parity drift.** If the PR
   adds a concept missing from the spec, either update the spec or push back on the
   PR. Drift compounds.

---

## How to start a task

**Touching one SDK only** (bug fix, local refactor, doc tweak, idiomatic
improvement): work in that SDK folder; read its own `README.md`/`AGENTS.md`. Before
finishing, check `sdks/parity-matrix.md` — if your change affects a row, update the
cell and decide whether other SDKs need a follow-up.

**Add/change a capability that should exist in every SDK:** use the
`add-sdk-feature` skill (starts at the spec, fans out).

**"This landed in SDK X, bring the others to parity":** use `propagate-change`.

**"Audit the fleet, where are we drifting?":** use `audit-parity`.

**"Start a new-language SDK":** use `scaffold-new-sdk`.

**"Run local e2e tests across all SDKs":** use `run-e2e-tests`.
- Preferred: `sdks/scripts/run-e2e-tests-docker.sh` (run from `sdks/`).
- The Docker wrapper avoids host toolchain drift; `sdks/scripts/run-e2e-tests.sh`
  is a host-toolchain fallback. The e2e `.env` lives at `sdks/.env` (gitignored).

**"Cut a coordinated major/minor train release":** use `release-synced`.

**"Cut a patch release for one core SDK":** use `release-sdk-patch`.

Skills live in `sdks/skills/<skill-name>/SKILL.md`.

---

## Commit convention

Commits follow the `lang-factory` repo-wide Conventional Commits 1.0.0 convention
(release-plz generates changelogs from them) plus the repo harness trailer rule.
Scope vocabulary specific to the SDK fleet:

- In **per-SDK repos** (`rust-sdk`, `web-sdk`, `go-sdk`, `python-sdk`): scope is a
  module or surface area — `feat(signer): …`, `fix(facade): …`,
  `docs(readme): …`. Skip the scope if the change spans the whole SDK.
- For **cross-cutting `sdks/` changes** (in `lang-factory`): scope is the SDK name —
  `feat(rust): …`, `feat(web): …` — or `spec` / `parity-matrix` / `docs`.

A change that breaks the public API or the spec MUST be flagged with a
`BREAKING CHANGE:` footer and/or a `!` after the type/scope. One concern per
commit: a diff touching the spec, an SDK, and the parity matrix is multiple
commits (or one only if it's strictly a coordinated submodule bump — see
`propagate-change`).

---

## What lives where

```
sdks/
├── AGENTS.md           ← this file (overrides parent for work under sdks/)
├── parity-matrix.md    ← living per-capability coverage matrix
├── sdk-spec/           ← normative, language-agnostic SDK spec
│   ├── README.md        ← spec index
│   ├── api-surface/     ← required capabilities (TII, TRP, facade, signers, errors, args)
│   ├── testing/         ← unit and e2e test strategy
│   ├── documentation/   ← README template, docstring requirements
│   └── test-vectors/    ← canonical shared fixtures (transfer/)
├── skills/
│   ├── audit-parity/         add-sdk-feature/    propagate-change/
│   ├── scaffold-new-sdk/     run-e2e-tests/
│   └── release-synced/       release-sdk-patch/
├── scripts/
│   ├── run-e2e-tests-docker.sh  ← canonical local cross-SDK e2e entrypoint
│   ├── run-e2e-tests.sh         ← host-toolchain fallback
│   └── Dockerfile
├── rust-sdk/    ← Tx3 Rust SDK   (submodule)
├── web-sdk/     ← Tx3 Web SDK    (submodule)
├── go-sdk/      ← Tx3 Go SDK     (submodule)
└── python-sdk/  ← Tx3 Python SDK (submodule)
```

The SDK subfolders are independent repos that release by tag, but core SDK package
versions follow the fleet-wide `MAJOR.MINOR` policy in
`sdks/sdk-spec/release-policy.md`.

---

## Non-goals for `sdks/`

- No shared source code. No cross-SDK build system. No monorepo tooling across SDK
  folders.
- No shared release binary or monorepo publish engine. Release automation stays
  per-SDK and tag-driven per `sdks/sdk-spec/release-policy.md`.
- No vendored Tx3 compiler or TRP server. SDKs consume those as external
  services/artifacts.

If you find yourself wanting to add any of the above, stop and propose a plan in
`lang-factory/plans/` first.
