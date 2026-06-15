---
name: release-plugins
description: Release the plugins/ grouping — gate the out-of-band marketplace publishes (vsce, plugin.json, vN tag move) and refresh soft compat notes.
---

# release-plugins

Release the `plugins/` grouping: editor / CI / agent integrations. None take a build-time Cargo pin —
they couple to the toolchain only through **soft compat notes** and runtime resolution — and each
publishes out-of-band (marketplace, git-source pointer, tag move). Instantiates the umbrella
[`grouping-contract.md`](../../../skills/release-toolchain/grouping-contract.md).

## When to use
- Invoked by the `release-toolchain` orchestrator after `tooling` released.
- Standalone to ship a plugin update independent of a toolchain release.

Do not use for anything that takes a Cargo pin — plugins don't.

## Scope
| Submodule | Type | Release mechanism |
| --- | --- | --- |
| `vscode-tx3` | `binary-dist` (marketplace) | manual `vsce publish` (`vscode:prepublish` script); resolves `tx3-lsp` from the user's PATH at runtime |
| `tx3-skills` | `pointer-only` (git-source marketplace) | bump `.claude-plugin/plugin.json` version + push `main`; the marketplace pulls from the git source. Carries a soft compat string ("Compatible with tx3 X.Y.x") |
| `actions` | `binary-dist` (GH Actions) | push tag `v<x.y.z>` → `release.yml` **force-moves the major `vN` tag** and cuts a GitHub release |

## Inputs
- `upstream_versions` — used only as **soft compat strings** (e.g. to update `tx3-skills`'s "Compatible
  with tx3 X" note), never as Cargo pins.
- `target_channel`, `scope`, `bump_policy` per the contract.

## Procedure
1. **Map scope.** Classify each in-scope plugin (table above).
2. **Bump versions + refresh compat notes.** `tx3-skills`: bump `plugin.json` version and update the
   "Compatible with tx3 X.Y.x" description to the released toolchain minor. `vscode-tx3`: bump
   `package.json` version. `actions`: bump as needed for the new `v<x.y.z>`.
3. **Verify** the plugin builds/packages (`npm run compile` / `vsce package --no-publish` for
   `vscode-tx3`; the Claude plugin manifest is valid JSON for `tx3-skills`).
4. **Gate — out-of-band publishes (irreversible, outward-facing).** State per plugin:
   - `vscode-tx3`: *"run `vsce publish` for `vscode-tx3 <version>`"*.
   - `tx3-skills`: *"push `tx3-skills` `main` with the bumped `plugin.json`"* (the marketplace serves the
     git source).
   - `actions`: *"push tag `v<x.y.z>` in `actions`"* (CI force-moves `vN` + cuts the release).

   **Stop and wait.** The agent never runs `vsce publish`, force-moves a tag, or pushes a marketplace
   pointer.
5. **Verify.** `gh release view --repo tx3-lang/actions v<x.y.z>` (+ the moved `vN`); the VSCode
   marketplace listing / the Claude marketplace pointer reflect the new versions.
6. **Report Outputs.**

## Outputs
- `binaries: { "actions": "vN" }`  (the moved major tag)
- `pointers: [ "plugins/<each updated plugin>" ]`
- `adopted: { ... }` — the toolchain versions recorded as soft compat notes (informational)

## Guardrails
- No Cargo pins here — thread `upstream_versions` only into compat strings/docs.
- `vsce publish`, the `vN` tag move, and the marketplace pointer push are irreversible, outward-facing —
  always developer gates.
- A plugin with no pending change is a no-op; don't bump versions just to bump them.

## Error handling
- **`vsce publish` rejected (version exists / token)** — confirm the `package.json` bump and the
  publisher token with the developer; don't retry blindly.
- **`actions` `vN` didn't move** — the `release.yml` force-move step failed; inspect
  `gh run view --repo tx3-lang/actions` and re-push the tag if needed.
- **`tx3-skills` compat note left stale** — easy to forget; verify the "Compatible with tx3 X" string
  matches the released minor before pushing `main`.
