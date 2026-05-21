# plugins — agent guide

Part of the Tx3 [`toolchain`](../AGENTS.md) umbrella. The `plugins/` grouping holds **editor,
CI, and agent integrations** that surface Tx3 in third-party environments. These are
downstream consumers — bump them after upstream changes in `core/`, `lang/`, and `tooling/`
have landed.

## Routing a change

- `plugins/vscode-tx3/` → [`tx3-lang/vscode-tx3`](https://github.com/tx3-lang/vscode-tx3) — the VSCode extension; consumes `tooling/tx3-lsp`.
- `plugins/tx3-skills/` → [`tx3-lang/tx3-skills`](https://github.com/tx3-lang/tx3-skills) — end-user coding-agent skills / Claude plugin for Tx3.
- `plugins/actions/` → [`tx3-lang/actions`](https://github.com/tx3-lang/actions) — reusable GitHub Actions for end-user Tx3 CI.

A submodule's own `AGENTS.md` / `CLAUDE.md` / `README.md` overrides this file for work inside
that path.
