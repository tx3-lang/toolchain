# Plan: trix codegen must emit package.json for the TS target

Status: **open / not started (small)**
Scope: `tooling/trix` — `trix codegen` for the TypeScript/built-in
plugin.
Origin: user feedback doc ("trix codegen: package.json not created at
gen/typescript").

## Context

`trix codegen` (delegating to `tx3c codegen`) does not emit a
`package.json` in the generated TS output dir, so the generated client
isn't directly runnable/installable. The other already-fixed trix
issues (forbidden `@`→`:` char [a], logo manifest fetch [b], sundae
case sensitivity [c]) should get regression tests so they don't return.

## Approach

1. Add a static `package.json` template to the web-sdk codegen
   templates (`.trix/client-lib/`) so it's copied verbatim into the
   output (non-`.hbs` files are copied as-is per the codegen contract).
   Or render one via `package.json.hbs` if dependencies need to vary.
2. Verify `trix codegen <ts plugin>` produces a `package.json` next to
   the generated `protocol.ts`.
3. Add regression e2e tests in `trix/tests/e2e/` for the three
   previously-fixed issues: `@`→`:` mapping, OCI logo-manifest fetch,
   and repo-name case sensitivity (`SundaeSwap-finance` vs
   `sundaeswap-finance`).

## References

- `plans/sdk-codegen-v1beta0-migration.md` — static-file copy rule;
  `.hbs`-vs-verbatim.
- `tooling/AGENTS.md`.

## Verification

- `trix codegen` emits `package.json`; `npm install` in the output dir
  succeeds.
- New `trix` e2e tests pass.

## Depends on / unblocks

- Pairs with `codegen-v1beta0` migration. Standalone otherwise.
