# Versioning

- The SDK fleet shares a coordinated `MAJOR.MINOR` version train across Rust/Web/Go/Python core SDK packages.
- Patch (`PATCH`) versions are independent at the SDK level.
- Canonical tag-triggered release rules and per-SDK publish mechanics are defined in [release-policy.md](release-policy.md).
- Each SDK's `README.md` MUST declare a **Tx3 protocol compatibility** line: which TRP protocol version and which TII schema version it speaks. Breaking changes to either force at minimum a minor bump across all SDKs.
- The parity matrix in `docs/parity-matrix.md` is a living artifact, not a released version.
- Pre-1.0 SDKs MAY break their public API within minors; from 1.0 onward they MUST follow strict semver.
