# API Surface

This section defines the capabilities every Tx3 SDK **MUST** implement. The spec uses a three-tier requirement model (RFC 2119):

| Tier | Keyword | Meaning | Where |
|------|---------|---------|-------|
| Required | **MUST** | Every SDK implements this. No exceptions. | This folder (`api-surface/`) |
| Recommended | **SHOULD** | Expected unless there's a good reason not to. | [scope.md (Recommended)](../scope.md#recommended-surface) |
| Optional | **MAY** | Nice-to-have; won't block compliance. | [scope.md (Optional)](../scope.md) |

---

## Components

The required surface is organized by component, mirroring how SDKs are typically structured:

| File | Component | Sections | What it covers |
|------|-----------|----------|----------------|
| [tii.md](tii.md) | TII | &sect;3.1 | Loading `.tii` files into `Protocol` objects |
| [trp.md](trp.md) | TRP | &sect;3.2 | Low-level `resolve`, `submit`, `checkStatus` client |
| [facade.md](facade.md) | Facade | &sect;3.3, &sect;3.4, &sect;3.6, &sect;3.7 | `Tx3Client`, `TxBuilder`, parties, profiles, wait modes |
| [signers.md](signers.md) | Signers | &sect;3.5 | `Signer` interface, `CardanoSigner`, `Ed25519Signer` |
| [errors.md](errors.md) | Errors | &sect;3.8 | Discriminated error hierarchy |
| [args.md](args.md) | Arguments | &sect;3.9 | Native-value marshalling to TRP wire format |

---

## Reading order

If you're implementing a new SDK, work through these in dependency order:

1. **TRP** — the transport layer everything else builds on
2. **TII** — protocol loading, needed by the facade for validation
3. **Signers** — independent of TRP/TII, can be built in parallel
4. **Facade** — ties TRP + TII + signers together
5. **Errors** and **Args** — cross-cutting, refine as you go
