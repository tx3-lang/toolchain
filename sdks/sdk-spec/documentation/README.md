# Documentation Requirements

Documentation is a first-class deliverable. An SDK that works but can't be understood by a new developer is incomplete.

## Overview

| Artifact | Scope | Where to find requirements |
|----------|-------|---------------------------|
| SDK README | Per-SDK | [readme-template.md](readme-template.md) |
| Docstrings | Per public symbol | [docstrings.md](docstrings.md) |
| Code examples | Per SDK | Included in README and docstrings |

## Principles

1. **A developer should go from zero to a submitted transaction in under 5 minutes** using only the README and the SDK's public API.
2. **Docstrings are the API reference.** Generated docs (rustdoc, TypeDoc, pdoc) are the primary way developers discover the API surface. Every public symbol must be documented.
3. **Examples are tests.** Wherever possible, code examples in docstrings should be runnable (Rust `///` examples, TypeScript `@example` blocks) or extracted into the `examples/` directory and tested in CI.
4. **The glossary is the single source of truth.** When documenting a concept, link to or quote the [glossary](../glossary.md) rather than inventing new descriptions.
