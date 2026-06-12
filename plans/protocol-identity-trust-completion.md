# Plan: protocol-identity & trust — completion of the deferred work

Status: **open / blocked on registry server for most workstreams**
Scope: `trix` (`tooling/trix`), registry (`registry/`), and the
shared design doc in `tooling/trix/design/003-protocol-interfaces.md`.
Origin: continuation of tx3-lang/trix#112 (publisher-side schema) and
tx3-lang/trix#113 (consumer-side scaffolding + stub verifiers).

## Context

The schema, cache shape, CLI surface, and verification *call sites*
for GitHub-anchored protocol identity already exist in trix as of
#113. What is missing is the *actual* identity proof: publishes are
still anonymous (`RegistryAuth::Anonymous`), the cached
`ProtocolManifest.tier` is always `Unverified`, and
`interfaces::attestation::verify_*` are stubs that return
`AttestationError::NotYetWired`. Trust pins parse and are enforced
for tier/repo mismatch, but a strict pin against an unverified
manifest only warns — promoting that to a hard error is meaningless
until verification can succeed.

Everything below plugs into seams that are *already in place*. No
schema migration is expected; no consumer-facing surface needs to
move. The work is mechanical once the registry ships its half.

Read in conjunction with the "Identity & trust" section of
`tooling/trix/design/003-protocol-interfaces.md`.

## Workstream A — Publish-side authentication (OIDC + GitHub App)

**Goal.** Replace `RegistryAuth::Anonymous` in `trix publish` with a
real bearer token, sourced from one of two tiers:

1. **OIDC (canonical).** Inside a GitHub Actions workflow, mint a
   workflow OIDC JWT with `aud=tx3-registry` and present it. The
   registry verifies the claim shape (`repository`,
   `repository_owner`, `ref`, `sha`, `workflow`) and asserts
   alignment with the requested `<scope>/<name>` before accepting
   the push.
2. **GitHub App device flow.** Outside CI, drive a device-flow
   exchange against the tx3 GitHub App; cache the short-lived
   token under `~/.config/trix/credentials.json`. Provenance is
   weaker (no commit/ref claim) and `[protocol].repository` still
   anchors the publish.

**Seams.**
- `commands/publish.rs` — the `oci_client.push(..., RegistryAuth::Anonymous, ...)` call.
- New module: `interfaces/auth.rs` (`acquire_oidc()`, `acquire_app_token()`, token cache).
- `commands/publish.rs` decides the tier from environment: CI env vars present → OIDC; otherwise device flow.

**Dependencies.**
- Registry-side OIDC verification (audience + claim shape against `<scope>/<name>`).
- GitHub App registration + server-side App-token verification.
- Scope-claim reservation API (first publish under a GitHub owner pins it; subsequent owners are refused).

**Verification.**
- Unit: `acquire_oidc()` errors cleanly when run outside GitHub Actions; honours `ACTIONS_ID_TOKEN_REQUEST_*` envs when set.
- Integration against a fake registry: token presented, audience accepted, claim shape parsed; scope mismatch rejected with a clear diagnostic.
- End-to-end manual: publish from a CI workflow against staging; publish from a laptop via device flow; both produce a verifiable artifact.

## Workstream B — Sigstore referrer (publish + verify, OIDC tier)

**Goal.** Make the registry no longer a trust root. At publish time
attach a sigstore bundle as an OCI 1.1 referrer; at consume time
verify against pinned Fulcio roots offline.

### B1. Publish — attach the bundle

After the existing image push, mint a Fulcio cert from the workflow's
OIDC token, sign the manifest digest, and push the bundle
(`application/vnd.dev.sigstore.bundle.v0.3+json`) as a referrer to the
just-pushed manifest digest. App-tier publishes skip this step; the
registry produces its own attestation instead (Workstream C).

**Seams.**
- `commands/publish.rs` — new step after the existing `block_on(client.push(...))`.
- `interfaces::oci` — referrer push helper (new function), parallel to today's `pull`/`reference_for`.

**Dependencies.** OCI 1.1 Referrers API on the registry server.

### B2. Consume — verify the bundle

Pull the referrer alongside the artifact; walk the cert chain to
`FULCIO_ROOT_CERT_PEM`; check OIDC issuer equals `GITHUB_OIDC_ISSUER`;
require cert claims `repository` / `repository_owner` to equal the
requested `<scope>/<name>`; populate `VerificationFacts { tier = GithubOidc, ... }`.

**Seams.**
- `interfaces::attestation::verify_sigstore_bundle` — stub today; this is where the real implementation lands.
- `interfaces::oci::pull` — extend to fetch the referrer bundle alongside the artifact, surface as `PulledArtifact { bundle, ... }`.
- `interfaces::write_cache` — copy `VerificationFacts` into `ProtocolManifest` (`tier`, `subject`, `fulcio_issuer`, `bundle_digest`, `verified_at`).

### B3. Pin real trust roots

Fill in the placeholder constants in `config::convention.rs`:
`FULCIO_ROOT_CERT_PEM` (the actual PEM, not the empty string),
`TX3_REGISTRY_SIGNING_KEY` (deferred to Workstream C),
`GITHUB_OIDC_ISSUER` (already correct), `FULCIO_ROOT_ISSUER` (already correct).

**Verification.**
- Unit: `verify_sigstore_bundle` against a golden-good bundle returns `VerificationFacts { tier = GithubOidc }`; rejects (a) wrong-repo claim, (b) wrong-owner claim, (c) expired cert, (d) cert from a non-Fulcio issuer.
- Integration: fake registry returns a manifest + referrer; `trix use` populates `ProtocolManifest.tier = GithubOidc` and the subject/issuer/bundle digest.
- Round-trip: re-running `restore_all` against a tampered `metadata.json` (tier downgraded by hand) re-verifies from the referrer and corrects.

## Workstream C — App-tier registry attestation

**Goal.** For publishes via the GitHub App device flow (no workflow
OIDC), the registry produces an Ed25519-signed attestation over the
manifest digest, signed with `TX3_REGISTRY_SIGNING_KEY`. Consumers
verify against the pinned pubkey.

**Seams.**
- `interfaces::attestation::verify_registry_attestation` — stub today; landing site for the Ed25519 verifier.
- `config::convention::TX3_REGISTRY_SIGNING_KEY` — fill in the real base64-encoded pubkey.
- `interfaces::oci::pull` — fetch the attestation blob (mechanism TBD with the registry team; likely a referrer of a different media type, or a sibling endpoint).

**Dependencies.** Registry-side App-token verification + attestation signing infrastructure.

**Verification.** Same shape as B2 — golden-good attestation passes; wrong-signer / wrong-digest / wrong-owner all fail.

## Workstream D — Promote scaffolding to enforcement

Once Workstreams B and C are real, the consumer-side surfaces stop
warning and start failing closed.

### D1. Trust pins become hard errors

`interfaces::check_trust` currently warns and returns `None` when
`manifest.tier == Unverified` and a pin is set. Remove that branch
(or invert it: an unverified manifest with a pin is a
`TrustViolation::TierMismatch`). Add a new variant
`TrustViolation::Unverified { alias, ... }` for the diagnostic.

**Seams.** `interfaces/mod.rs::check_trust` (the `eprintln!` warn branch); `interfaces::TrustViolation` enum.

### D2. `--require=oidc` runs the real verifier

`interfaces::add` currently routes `TrustPolicy::RequireOidc` through
the stub which always errors. Once B2 lands, the same call succeeds
when a valid bundle is present and errors only when verification
genuinely fails. No code change to the dispatcher — only the
stub-becomes-real change in Workstream B.

### D3. Publisher annotations on the manifest

Emit `land.tx3.protocol.publisher.kind` (`github-oidc` | `github-app`)
and `land.tx3.protocol.publisher.subject` (OIDC subject for OIDC tier;
GitHub login for App tier) on the OCI manifest. Mirror into
`ProtocolManifest.subject` on the consume side.

**Seams.** `commands/publish.rs` annotations map; `interfaces::write_cache` already copies `subject` once `VerificationFacts` carries it.

### D4. Git-ref narrowing in trust pins

`TrustedPublisher.git_ref` is parsed but ignored by `check_trust`
(`let _ = pin.git_ref`). Once `VerificationFacts.git_ref` is
populated from the workflow's `ref` claim (B2), compare them and
add `TrustViolation::GitRefMismatch`.

**Seams.** `interfaces/mod.rs::check_trust`; `interfaces::TrustViolation` enum.

## Out of scope (server-side, not in this repo)

These are not trix work; listed so the dependency surface is explicit.

- Registry-side OIDC token verification (audience + claim shape against `<scope>/<name>`).
- OCI 1.1 Referrers API support on the registry.
- GitHub App registration + App-token verification.
- Server-side attestation signing (Ed25519, key custody).
- Scope-claim reservation API.
- Revocations endpoint (future; affects neither publish nor verify in v1).

## Suggested ordering

Once the registry is ready:

1. **A** — auth on publish (unblocks every subsequent publish).
2. **B1** — sigstore referrer push (depends on A producing a token; otherwise nothing to sign with).
3. **B2 + B3** — sigstore verify + real Fulcio root (depends on B1 producing bundles to verify).
4. **D2** — `--require=oidc` end-to-end (free fallout of B2).
5. **D1** — flip trust-pin warn → fail (depends on B2 to produce a non-`Unverified` tier).
6. **D3** — publisher annotations (small; can land anywhere after A).
7. **C** — App-tier attestation (parallelizable with B once registry side is ready).
8. **D4** — git-ref narrowing (last; depends on B2 populating `git_ref` from the workflow claim).

Workstreams A through D3 together complete the OIDC tier end-to-end;
C lights up the App tier; D4 is a refinement. The PR cadence should
mirror the workstreams (4–6 PRs total on trix), each independently
shippable behind the existing stub seams.

## Verification across workstreams (negative tests worth keeping)

- Publish `scope=acme` from a repo whose owner is `bob` — registry must refuse; `trix publish` surfaces the rejection clearly.
- Consume an artifact whose referrer was signed for a different repo — `verify_sigstore_bundle` rejects.
- Consume an artifact whose Fulcio cert is expired — rejects.
- Consume an artifact with no referrer when `--require=oidc` is set — rejects with the "missing attestation" diagnostic (not the current `NotYetWired`).
- Hand-edit `ProtocolManifest.tier = GithubOidc` while leaving `bundle_digest = None` — re-verify must catch the inconsistency.

## References

- `tooling/trix/design/003-protocol-interfaces.md` § Identity & trust
- tx3-lang/trix#112 — publisher-side schema (merged)
- tx3-lang/trix#113 — consumer-side scaffolding + stubs (merged)
