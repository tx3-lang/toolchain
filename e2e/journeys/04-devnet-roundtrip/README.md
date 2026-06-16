# 04-devnet-roundtrip

The integration centerpiece: scaffold the default project and run a real `trix test`. It spins a
local Dolos devnet, restores deterministic cshell wallets, submits the scaffolded transfers, and
asserts the resulting balances — exercising trix + tx3c + dolos + cshell + the resolver together.

- **Scope:** runtime (needs a working devnet). No secrets, no live network beyond the one-time install.
- **Channels:** runs everywhere (no `tx3c` floor); scheduled on both the **stable** and **beta** jobs.

The balance-assertion phase depends on `trix test`'s expect/balance handling, repaired in trix 0.26.1
(tx3-lang/trix#123: the expect path had queried the wrong cshell store, passed the `@bob` placeholder,
and parsed a mismatched utxo shape). The assertion is **strict** (not a tolerated `xfail`).
