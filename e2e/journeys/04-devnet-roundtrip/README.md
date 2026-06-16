# 04-devnet-roundtrip

The integration centerpiece: scaffold the default project and run a real `trix test`. It spins a
local Dolos devnet, restores deterministic cshell wallets, submits the scaffolded transfers, and
asserts the resulting balances — exercising trix + tx3c + dolos + cshell + the resolver together.

- **Scope:** runtime (needs a working devnet). No secrets, no live network beyond the one-time install.
- **Channels:** runs everywhere (no `tx3c` floor), but the CI workflow currently schedules it on the
  **beta** job only.

## Currently failing on released channels — intentionally

The balance-assertion phase hits a known, tracked trix bug (the expect path queried the wrong cshell
store, passed the `@bob` placeholder, and parsed a mismatched utxo shape). Fixed on trix `main`
(tx3-lang/trix#123) but not yet in a released channel, so this journey **fails** on released binaries.
The assertion is kept **strict** (not a tolerated `xfail`) so the broken round-trip is a real,
visible failure. It goes green automatically once the fix ships to a channel; at that point add this
journey to the `stable` job too.
