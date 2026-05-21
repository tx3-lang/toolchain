# toolchain

The Tx3 toolchain: the source of truth for Tx3 toolchain release versions, and a
meta-repository that aggregates the [Tx3](https://github.com/tx3-lang) toolkit as git submodules
so coding agents (and humans) have a single entry point for cross-cutting changes — features,
fixes, and refactorings that span more than one repo.

- **Release manifests** — `manifest-stable.json`, `manifest-beta.json`, and
  `manifest-nightly.json` pin the component versions shipped on each release channel.
- **Toolkit submodules** — the language (`lang/tx3`), the specs (`core/tii`, `core/tir`,
  `core/trp`), the tooling (`tooling/trix`, `tooling/tx3up`, `tooling/tx3-lsp`, `tooling/tx3-mcp`,
  `tooling/tx3-lift`), the plugins (`plugins/vscode-tx3`, `plugins/tx3-skills`,
  `plugins/actions`), the backends (`backends/tx3-hydra`, `backends/protocol-gateway`), the
  protocol `registry`, and the public `docs`.
- **SDK fleet** — the per-language SDKs (rust/web/go/python) and their cross-cutting spec live
  under [`sdks/`](./sdks/AGENTS.md).

Agents: see [`AGENTS.md`](./AGENTS.md). `CLAUDE.md`, `GEMINI.md`, and
`.github/copilot-instructions.md` are short pointer files that defer to it.
