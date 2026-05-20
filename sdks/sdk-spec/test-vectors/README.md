# Test Vectors

This directory contains canonical, spec-level e2e vectors shared across all Tx3 SDKs.

## Conventions

- Each vector lives in its own subdirectory.
- A vector MAY include:
  - a source `.tx3` file (human-readable intent),
  - a compiled `.tii` file (SDK runtime fixture),
  - profile-specific `.env` examples used by e2e tests.
- SDKs MAY copy or symlink vectors into local fixture paths, but spec references MUST target files in this directory.

## Available vectors

- `transfer/`
  - `transfer.tx3`
  - `transfer.tii`
  - `transfer.preprod.env`
