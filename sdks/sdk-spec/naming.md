# Naming Conventions

- **Concept names** from the [glossary](glossary.md) are fixed. Translate only casing to the host language — never meaning.
- **Builder step order** (`tx -> arg -> resolve -> sign -> submit -> waitForConfirmed / waitForFinalized`) is fixed.
- **Error category names** (see [error model](api-surface/errors.md)) SHOULD appear verbatim in error type names (`UnknownParty`, `MissingParams`, `SubmitHashMismatch`, `FinalizedFailed`, `FinalizedTimeout`).
- **File / module layout** is a host-language concern; the Rust SDK's `core / facade / tii / trp` split is a suggestion, not a requirement.
