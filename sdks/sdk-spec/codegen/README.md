# Codegen

This section defines the contract between a Tx3 **codegen plugin** (per-language template set) and the toolchain that drives it (`tx3c codegen`, invoked by `trix codegen`).

A codegen plugin is an *optional* SDK capability per [scope.md](../scope.md). If an SDK ships one, it MUST meet the requirements in this folder. The same contract is the target for third-party plugins addressed by `(repo, path, ref)` in `trix.toml`.

The requirement keywords **MUST**, **SHOULD**, and **MAY** are used as in RFC 2119. The reference plugins live at `sdks/{web,rust,python,go}-sdk/.trix/client-lib/`; when prose here is ambiguous, the `web-sdk` template is the tiebreaker for *shape*.

## Components

| File | Covers |
|------|--------|
| [inputs.md](inputs.md) | The data context templates render against |
| [renderer-contract.md](renderer-contract.md) | The Handlebars helpers and rules `tx3c codegen` enforces |
| [generated-surface.md](generated-surface.md) | The minimum public symbols generated bindings must expose |
| [plugin-layout.md](plugin-layout.md) | Where templates live and how `trix` addresses them |
| [versioning.md](versioning.md) | Lockstep between TII schema version and plugin ref |
| [testing.md](testing.md) | The render-fixture test every plugin must ship |

Read in that order if you're authoring a new plugin.
