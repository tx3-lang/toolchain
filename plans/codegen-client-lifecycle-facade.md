# Plan: generated codegen clients expose the full transaction lifecycle

Status: **open / not started — docs already ship the target API**
Scope: the four SDK submodules' codegen templates under
`sdks/{web,rust,python,go}-sdk/.trix/client-lib/`; possibly the SDK runtime
libraries. No `trix`/`tx3c` change expected (codegen is already delegated).
Origin: accepted follow-up from the "codegen as the primary consuming flow"
docs rework ([tx3-lang/docs#51], merged). See [[consuming-docs-ahead-of-codegen]].
Related: [`sdk-codegen-v1beta0-migration.md`](./sdk-codegen-v1beta0-migration.md)
— same `.trix/client-lib/` templates; sequence the two together.

## Context

The Consuming Protocols docs now present `trix use` + `trix codegen` as the
primary integration mechanism, and `docs/consuming/quick-start.mdx` shows a
generated typed `Client` that owns the **whole** transaction lifecycle.

The generated client does not do that yet. The codegen Handlebars templates
(`sdks/*/.trix/client-lib/*.hbs`) emit a thin `Client` that wraps the
low-level `TrpClient` only:

- constructor takes `(ClientOptions, profile?)`;
- one typed method per transaction that **resolves** and returns an
  *unsigned* `TxEnvelope`;
- a raw `submit(params)` pass-through.

It has **no** party/signer binding, no `withProfile`/`withParty` builder, no
`sign`, and no `waitForConfirmed`/`waitForFinalized`. The elegant
`resolve → sign → submit → wait` chain lives only in the runtime SDK's
high-level `Tx3Client` facade — which today is the *dynamic* path (takes a
`Protocol` object, addresses transactions by string name).

So the Quick Start is intentionally written ahead of the code. This plan
closes the gap: make `trix codegen` emit a typed client that exposes the full
facade, so the Quick Start becomes runnable as written.

## Target surface (from the shipped docs)

`docs/consuming/quick-start.mdx` is the contract this work must satisfy
(TypeScript shown; every SDK must reach an idiomatic equivalent):

```ts
import { Client } from "./gen/transfer";
import { Party, Ed25519Signer, PollConfig } from "tx3-sdk";

const client = new Client({ endpoint: "http://localhost:8164" })
  .withProfile("local")
  .withParty("sender", Party.signer(signer))
  .withParty("receiver", Party.address("addr_test1..."));

const status = await client
  .transfer({ quantity: 10_000_000n })   // typed, per-tx method
  .resolve()
  .then((r) => r.sign())
  .then((s) => s.submit())
  .then((sub) => sub.waitForConfirmed(PollConfig.default()));
```

Required generated-`Client` surface, per language:

- a constructor taking TRP connection options;
- `withProfile(name)` — select an embedded profile;
- `withParty(name, Party)` — bind a signer or a read-only address;
- one typed method per transaction returning the lifecycle chain handle
  (`ResolvedTx → SignedTx → SubmittedTx`), not a bare `TxEnvelope`;
- `resolve / sign / submit / waitForConfirmed / waitForFinalized` reachable
  from that chain, reusing the SDK's `PollConfig`.

## Key design decision

The generated client embeds protocol metadata at codegen time and must not
need a `.tii` at runtime. Two ways to give it the lifecycle:

- **Design A — layer codegen on the runtime facade.** The generated client
  embeds the full TII JSON, internally builds `Protocol.fromJson(EMBEDDED)`
  + a `Tx3Client`, and each typed method is thin sugar over
  `.tx(name).arg(...)`. Smallest change — the facade (`Tx3Client`, `Party`,
  `TxBuilder`, `ResolvedTx/SignedTx/SubmittedTx`, `PollConfig`) already
  exists; codegen just adds typed wrappers. Trade-off: bends the
  "codegen and `Protocol.fromFile` are parallel paths" principle in
  `sdks/sdk-spec/codegen/` and embeds the whole TII rather than per-tx TIR.

- **Design B — extend the SDK facade to run on embedded TIR.** Keep codegen
  embedding per-transaction TIR envelopes + profiles (today's shape), and
  add SDK facade entry points so party binding, signing, and polling work
  from a bare TIR envelope without a `Protocol`. Honors the codegen design
  principle and keeps generated output minimal, but is a larger, four-repo
  SDK change.

**Recommendation:** decide with the SDK maintainers; Design A is materially
less work and ships the runnable Quick Start fastest. If the "parallel
paths" principle is load-bearing, do B. This decision gates everything below
and must be settled first.

## Approach (per SDK repo, identical shape)

1. Settle Design A vs B (above).
2. Update `.trix/client-lib/` templates in each SDK repo so the generated
   `Client` exposes the target surface — `withProfile`/`withParty` builder,
   typed per-tx methods returning the lifecycle chain.
3. If Design B: add the required facade entry points to each SDK runtime lib.
4. Validate end-to-end (see Verification), then tag the templates ref.

Recommended order: **rust-sdk first** (compiles locally, fastest feedback,
reuse the `trix` e2e harness), then web/python/go.

## Coordination with the v1beta0 migration

[`sdk-codegen-v1beta0-migration.md`](./sdk-codegen-v1beta0-migration.md) is an
open plan to (re)author the same `.trix/client-lib/` templates against the
`tx3c codegen` contract under the `codegen-v1beta0` ref. That work and this
work touch the **same files**. Do them as one pass per SDK repo — author the
v1beta0 templates already exposing the full lifecycle facade — rather than
landing a resolve-only client and rewriting it immediately after.

## Critical references

- `docs/consuming/quick-start.mdx` — the target API contract (all four langs).
- `docs/consuming/dynamic-usage.mdx` — the `Tx3Client` facade as it exists
  today; the lifecycle building blocks the generated client must reuse.
- `sdks/*/.trix/client-lib/*.hbs` — the templates to change.
- `sdks/sdk-spec/codegen/` — the codegen surface spec (notably the
  "parallel paths" principle that Design A bends).
- `sdks/web-sdk` runtime: `Tx3Client`, `Party`, `TxBuilder`,
  `ResolvedTx/SignedTx/SubmittedTx`, `PollConfig`, `Protocol.fromJson` —
  the facade pieces to wrap (Design A) or extend (Design B).
- `tooling/trix/src/config/convention.rs` — confirms `trix` needs no change
  (codegen is fully delegated; plugins resolve to `.trix/client-lib`).

## Verification (per SDK, end-to-end)

- Run `trix use` + `trix codegen` on a scratch project, then execute the
  exact `docs/consuming/quick-start.mdx` snippet for that language against a
  `trix devnet` TRP endpoint — it must compile/run unmodified.
- Confirm the generated `Client` signatures match the docs verbatim
  (`withProfile`, `withParty`, per-tx method names, `PollConfig`); fix
  whichever side is wrong so docs and code agree.
- Extend a `trix` e2e (mirror `codegen_deps`) that generates a client and
  type-checks/compiles it for at least rust-sdk in CI.

## Risks / notes

- **The docs are live and ahead of the code right now.** Until this lands,
  the Quick Start describes methods the generated client lacks. Keep the
  reviewer note in [tx3-lang/docs#51] in mind; if this slips, consider a
  short `<Aside>` in the Quick Start flagging the typed lifecycle as rolling
  out.
- Final `Client` signatures are the join point — docs and generated code
  must be reconciled in lockstep when this ships.
- Do not bump the `stable` toolchain channel on the back of this until all
  four SDKs ship and validate (same caveat as the v1beta0 migration plan).

[tx3-lang/docs#51]: https://github.com/tx3-lang/docs/pull/51
