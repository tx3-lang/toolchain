# Glossary

These are the authoritative names for the concepts every SDK exposes. **SDKs MUST use these names, translated only for casing** (e.g. `wait_for_confirmed` / `waitForConfirmed` / `WaitForConfirmed`). Do not invent synonyms.

| Term             | Definition                                                                                                                                            |
|------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Tx3 DSL**      | The high-level declarative language used in `.tx3` source files to describe parties, environment, and transactions.                                   |
| **`.tx3` file**  | Source artifact written by the user in the Tx3 DSL. Compiled by the Tx3 toolchain.                                                                    |
| **TII**          | *Transaction Invoke Interface*. The compiled form of a `.tx3` file — a JSON document describing the protocol: parties, env schema, transactions, params. |
| **`.tii` file**  | On-disk serialization of a TII document.                                                                                                              |
| **Protocol**     | The in-memory representation of a loaded TII. The object a developer loads and queries for available transactions and their params.                    |
| **TRP**          | *Transaction Resolve Protocol*. JSON-RPC protocol exposed by a TRP server. Core methods: `trp.resolve`, `trp.submit`, `trp.checkStatus` (or equivalent).|
| **TRP client**   | Low-level HTTP/JSON-RPC client that speaks TRP. Takes an endpoint + optional headers.                                                                  |
| **Party**        | A named participant in a transaction, declared in the `.tx3`. Either an address-only party (read-only) or a signer party (can produce witnesses).     |
| **Signer**       | An object capable of producing a `Witness` for a given `SignRequest`. Must expose the address it corresponds to.                                       |
| **SignRequest**  | Input to `Signer.sign`. Carries the bound tx hash (`txHashHex`) and the full tx CBOR (`txCborHex`). Hash-based signers read the former; tx-based signers (wallet adapters) read the latter. |
| **Profile**      | A named environment configuration (e.g. `preprod`, `mainnet`) applied to every invocation from a client.                                              |
| **TxBuilder**    | Fluent builder returned by the client for a given transaction name. Accepts args and terminates in `resolve()`.                                       |
| **Invocation**   | A partially-built transaction request: name + args + profile + parties. Produced by `TxBuilder`, consumed by `resolve()`.                             |
| **Witness**      | A signature payload bound to a tx hash: public key, signature bytes, witness type (e.g. `vkey`).                                                      |
| **External witness** | A `Witness` produced outside any registered `Signer` (e.g. by a hardware device, browser wallet, or remote signer) and attached to a `ResolvedTx` via `addWitness` before `sign()`. |
| **ResolvedTx**   | Output of `resolve()`. Carries the hash the signers will sign and the raw transaction bytes.                                                          |
| **SignedTx**     | Output of `sign()`. Ready for submission.                                                                                                             |
| **SubmittedTx**  | Output of `submit()`. Has the chain hash and can be polled for status.                                                                                |
| **Stage**        | The lifecycle state of a submitted tx. At least: `Confirmed`, `Finalized`, `Dropped`, `RolledBack`.                                                   |
| **PollConfig**   | Configuration for the wait loop: `attempts` + `delay`. MUST have sensible defaults (see [wait modes](api-surface/facade.md#37--wait-modes)).           |
