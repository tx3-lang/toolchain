# Naming Conventions

- **Concept names** from the [glossary](glossary.md) are fixed. Translate only casing to the host language — never meaning.
- **Builder step order** (`Protocol.client -> trp/trpEndpoint -> withProfile/withParty/withEnvValue -> build -> tx -> arg -> resolve -> sign -> submit -> waitForConfirmed / waitForFinalized`) is fixed.
- **Setter prefix convention** on `Tx3ClientBuilder`: mandatory settings (TRP options) carry **no** `with` prefix (`trp`, `trpEndpoint`); optional settings carry the host language's `with` prefix (`withProfile`, `withParty`, `withParties`, `withHeader`, `withEnvValue`). See [api-surface/facade.md §3.3](api-surface/facade.md#construction-must).
- **Error category names** (see [error model](api-surface/errors.md)) SHOULD appear verbatim in error type names (`UnknownParty`, `UnknownProfile`, `UnknownTx`, `MissingTrpEndpoint`, `SubmitHashMismatch`, `FinalizedFailed`, `FinalizedTimeout`).
- **File / module layout** is a host-language concern; the Rust SDK's `core / facade / tii / trp` split is a suggestion, not a requirement.
