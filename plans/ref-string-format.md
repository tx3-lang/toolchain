# Plan: protocol/tx reference string format — hardening & evolution

Status: **open / not started**
Scope: cross-cutting — `trix` (`src/refs.rs`, `src/oci.rs`, `src/config`),
the `registry`, and the future `trix publish` transitive-interface work.
Origin: design review of the canonical ref grammar introduced with
`trix use` / interfaces (PR tx3-lang/trix#109).

## Context

The canonical grammar (one parser, used by CLI + `trix.toml` + errors):

```
protocol_ref ::= alias | SCOPE "/" NAME [":" VERSION]
tx_ref       ::= [protocol_ref "::"] TX_NAME
IDENT/SCOPE/NAME/TX ::= [a-zA-Z_][a-zA-Z0-9_.-]*
VERSION             ::= [a-zA-Z0-9_][a-zA-Z0-9_.-]*   (OCI tag)
disambiguation: a `/` ⇒ registry ref; first `::` splits protocol/tx; bare ⇒ project
```

Verdict from the review: well-judged for today, idiomatically consistent
with both OCI (`scope/name:version`) and tx3-the-language (`::` paths, cf.
`cardano::withdrawal`). The registry is kept out of the ref (Cargo-style),
which is the right call. Two issues are worth acting on proactively; the
rest are deferrable **seams** that must merely be kept open.

## Workstream A — correctness: grammar must be ⊆ OCI (do now)

**Problem.** `IDENT` admits uppercase and a leading `_`; OCI repository
paths are `[a-z0-9]+([._-][a-z0-9]+)*` (lowercase, no leading separator).
So `Acme/Widget` / `_x/y` parse as valid `ProtocolRef` but are **not valid
OCI references** — a parsed ref is not guaranteed pushable/pullable. Today
this surfaces as a late, opaque failure inside `reference_for()` / the OCI
client instead of a clean parse error.

**Decision required.** Tighten the grammar to a subset of OCI naming, vs.
validate at `reference_for()`. Recommendation: **tighten the grammar** for
`SCOPE`/`NAME` (keep alias/`TX_NAME` as-is — those are local identifiers,
not registry coordinates) so the error is reported once, at parse, with the
same diagnostic everywhere.

**Steps.**
1. Add OCI-name validation for the `SCOPE` and `NAME` segments of
   `ProtocolRef::Registry` in `trix/src/refs.rs` (new `ParseError` variant,
   `miette::Diagnostic`).
2. Decide alias/`TX_NAME`: leave permissive, but add an early
   resolve-time check (or parse-time) so `my-tx::…` fails as a parse error
   rather than a resolve miss. (Lower priority; document the chosen
   behaviour.)
3. Add a parser-level invariant + test: **a version may never contain `:`**
   (the entire `:` vs `::` disambiguation rests on this; it is currently an
   implicit cross-module invariant, not asserted where the split happens).
4. Round-trip + rejection unit tests for the new constraints; update
   `trix/design/003-protocol-interfaces.md` grammar block.

Risk: low. No persisted-data migration (refs already in the wild that
violate OCI would have failed at pull anyway).

## Workstream B — commit to the multi-registry model (decide now, before transitive interfaces ship)

**Problem.** The grammar has no host slot and `(scope, name)` is treated as
a *global* identity (the dedupe rule and resolver assume `acme/widget` is
unique). That is true only under a single registry. The forcing function is
the already-planned `trix publish` recording an artifact's own interfaces:
once a ref is persisted in a published artifact, a *different* consumer must
resolve it — it must carry enough to find its registry. Resolving this
*after* refs are embedded in published artifacts is a migration, not a
tweak.

**Decision required (this is the load-bearing one).** Pick the federation
model:

- **B1 (recommended) — Cargo-style, out of band.** Keep the ref host-free.
  Add `[registries.<name>] url = …` to `trix.toml` and an optional
  per-interface `registry = "<name>"`. Identity becomes
  `(registry, scope, name)`. Auth/private registries attach to the named
  registry. **Zero grammar change.** For transitive interfaces, a published
  artifact records `(registry-url, scope, name, version, digest)` — the
  registry is data, not syntax.
- **B2 — Terraform/Docker-style, host-in-ref.** Optional leading `HOST/`,
  default elided. Re-imports the "first segment: host or scope?" ambiguity
  the current grammar deliberately avoids; needs a `.`/`:`-in-first-segment
  heuristic. Only justified if refs must be *self-contained* strings across
  org boundaries.

**Steps (assuming B1).**
1. Write the decision down (this file → "Decision" section) and reflect it
   in `trix/design/003-protocol-interfaces.md`.
2. Generalize identity to `(registry, scope, name)`:
   - `validate_interfaces` dedupe key, `Resolver` lookup, `cache_paths`
     layout (cache path likely gains a registry segment — confirm before
     it ossifies, since it is user-visible under `.tx3/tii/`).
   - `RootConfig`: `[registries.<name>]` map; `InterfaceEntry` optional
     `registry` field (default = the configured default registry name).
3. Define the **published-artifact interface record** shape for the future
   `trix publish` work so it is registry-aware from day one (OCI annotation
   `land.tx3.interfaces`, carrying registry URL + ref + digest).
4. Migration note: single-registry `trix.toml` files must keep working
   (`registry` omitted ⇒ default). `#[serde(default)]` everywhere.

Risk: medium, but **strictly lower if done before** transitive interfaces
and before the `.tx3/tii/` cache layout is treated as stable.

## Deferrable seams — keep open, do not foreclose

- **Digest-in-ref.** No `@sha256:…` form (digest is a sidecar field). Fine
  while `trix.toml` is the lockfile. Leave a grammar seam for an optional
  trailing `@digest`; do not repurpose `@` for anything else.
- **Version constraints / manifest-vs-lock split.** `trix.toml` is both
  manifest and lockfile; version is an exact tag. If a Cargo-style
  `*.toml` / `*.lock` split is ever introduced, the manifest side will want
  range syntax (`^1.2`). Don't ossify `trix.toml` semantics in a way that
  blocks introducing a separate lock later.
- **Nested scope.** Exactly one `/` (`MalformedScope` on two). Forecloses
  `org/team/widget`. Cheap to keep possible; only revisit if nested
  namespaces become plausible.
- **CLI seam.** Addressing is split across two arg shapes
  (`inspect tir --tx <TxRef>` vs `invoke --from <ProtocolRef>`); "interface,
  tx chosen interactively" is only expressible in one. Acceptable; note it
  so the "one grammar everywhere" claim stays honest.

## Sequencing

1. **A** (independent, low-risk, correctness) — can land anytime.
2. **B decision** — make the call (B1 vs B2) and record it here **before**
   any work on transitive interfaces or before the `.tx3/tii/` layout is
   declared stable.
3. **B implementation** — gated by the decision; bundle the cache-layout
   and published-record shape so the registry dimension is introduced once.
4. Deferrable seams — no action; reviewed whenever the grammar is next
   touched.

## Decision log

- _(unset)_ A: tighten grammar vs validate at `reference_for()` →
  recommended **tighten**.
- _(unset)_ B: federation model → recommended **B1 (Cargo-style out of
  band)**.
