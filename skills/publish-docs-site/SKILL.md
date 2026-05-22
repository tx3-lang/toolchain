# Publish Docs Site Skill

## Purpose
Publish the latest Tx3 docs to the company-wide documentation site
(`docs.txpipe.io`) by triggering the publish pipeline on `txpipe/docs`,
following it through to deploy, and verifying the rendered result.

The company docs site lives in [`txpipe/docs`](https://github.com/txpipe/docs)
and embeds the Tx3 docs (`tx3-lang/docs`) as a git submodule. Publishing is a
**three-stage pipeline**, not a single workflow — see Context.

## Prerequisites
- GitHub CLI (`gh`) installed and authenticated, with access to the
  `txpipe/docs` repository.
- `curl` available for the verification step.
- The docs changes you want published are **already merged into the default
  branch of `tx3-lang/docs`** — the workflow pulls whatever is current there;
  it does not pick up unmerged branches or PRs.

## Context

Publishing on `txpipe/docs` is a chain of three workflows; each stage
triggers the next:

1. **`Update Submodules`** (`update-submodules.yml`) — manually dispatched
   (`workflow_dispatch`, no inputs). Runs `git submodule update --remote`,
   and *if anything changed* commits it as `ci: update submodules to latest
   commit` (this touches `submodules/tx3`, and possibly other submodules
   such as `dolos`/`metis`). Finishes in ~20s.
2. **`Build`** — triggered by that commit (`workflow_run` event). Builds the
   static site.
3. **`Deploy`** — triggered by `Build` completing (`workflow_run` event).
   Publishes to `docs.txpipe.io`.

Key consequences — these are the things this skill exists to get right:

- **Watching only the `Update Submodules` run is not enough.** It finishes
  in seconds; the real work (`Build` → `Deploy`) happens afterwards. You must
  follow the chain to a successful `Deploy`.
- **No change ⇒ no build.** If `tx3-lang/docs` has not changed since the last
  publish, `Update Submodules` makes no commit, so `Build` and `Deploy` never
  fire. The site is already current — that is a success, not a failure.
- **Propagation lags the deploy.** Even after `Deploy` succeeds, a **brand-new
  route** (a page that did not exist before) can take noticeably longer to
  serve `200` than an edit to an existing page, and may briefly return `404`
  or `502` while CDN routing catches up.

- **Rendered output:** https://docs.txpipe.io/tx3

## Procedure

### 1. Confirm the docs are merged
Verify the changes to publish are on the default branch of `tx3-lang/docs`.
If they are still in an open PR, stop — merge first, otherwise this skill
publishes stale content.

### 2. Trigger the pipeline
```bash
gh workflow run update-submodules.yml --repo txpipe/docs
```

### 3. Watch `Update Submodules`
Wait a few seconds for the run to register, then resolve and watch it:
```bash
us_id=$(gh run list --repo txpipe/docs --workflow update-submodules.yml \
  --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$us_id" --repo txpipe/docs --exit-status
```
Confirm via `createdAt` that this is the run you just dispatched, not a
stale one.

### 4. Check whether it produced a commit
`Update Submodules` only kicks off a build if it actually committed a change.
Inspect the current `txpipe/docs` HEAD:
```bash
gh api repos/txpipe/docs/commits/main \
  --jq '.sha[0:9], .commit.committer.date, (.files[].filename)'
```
- **Fresh `ci: update submodules to latest commit` touching `submodules/tx3`**
  → a build was triggered; continue to step 5.
- **No new commit** → `tx3-lang/docs` was already current; no rebuild will
  run. Skip to step 7 and simply confirm the site is healthy.

### 5. Watch `Build`
The commit triggers a `Build` run (`workflow_run` event). Give it a few
seconds to appear, list the recent runs, and watch the newest `Build`:
```bash
gh run list --repo txpipe/docs --limit 6 \
  --json databaseId,workflowName,status,conclusion,event,createdAt
gh run watch <build_id> --repo txpipe/docs --exit-status
```

### 6. Watch `Deploy`
`Build` completing triggers a `Deploy` run. Locate and watch it the same way:
```bash
gh run list --repo txpipe/docs --limit 6 \
  --json databaseId,workflowName,status,conclusion,event,createdAt
gh run watch <deploy_id> --repo txpipe/docs --exit-status
```
Only once `Deploy` succeeds is the new content actually being published.

### 7. Verify the rendered site
Check the live URL returns `200`:
```bash
curl -sS -o /dev/null -w '%{http_code}\n' https://docs.txpipe.io/tx3
```
Then confirm the page reflects the change — fetch it and grep for a string
unique to this update (a new heading, page title, or section):
```bash
curl -s https://docs.txpipe.io/tx3/<changed-page> | grep -F "<expected text>"
```
Propagation guidance:
- Edits to **existing** pages are usually live within a couple of minutes of
  `Deploy` succeeding.
- **Newly added** pages/routes can take up to ~15 minutes; a `404` or `502`
  during that window is propagation lag, not failure. Re-check every ~30s
  before concluding anything is wrong.

## Decision Guidelines

### When to run this skill
- After a docs PR merges into `tx3-lang/docs` and you want it live.
- When asked to "publish", "deploy", or "update" the company docs site.

### What to grep for in verification
- Pick a string that is **new** in this update so a stale cache can't pass
  the check — e.g. a heading or page added by the merged PR.
- If you only need to confirm the site is healthy (not a specific change),
  a `200` plus the presence of known Tx3 docs content is sufficient.

### Re-running
- The pipeline is idempotent — safe to re-run.
- If `Build` or `Deploy` fails, fix the cause and re-trigger from step 2.
  Note: re-running `Update Submodules` when there is no new submodule change
  produces **no** commit and therefore **no** build (see step 4).

## Safety Checks
- [ ] Target changes merged into `tx3-lang/docs` before triggering.
- [ ] `gh auth status` succeeds and the account can dispatch workflows on
      `txpipe/docs`.
- [ ] Each run id watched is the freshly-created one, not a prior run.
- [ ] The pipeline was followed all the way to a successful **`Deploy`** —
      not just `Update Submodules`.
- [ ] Verification confirms `200` **and** content unique to the update —
      not just that the URL responds.

## Example Workflow
```
User: "Publish the latest docs to the company site"

→ Confirm the docs PR is merged into tx3-lang/docs main
→ gh workflow run update-submodules.yml --repo txpipe/docs
→ Watch Update Submodules → success (~20s)
→ Check txpipe/docs HEAD: fresh "ci: update submodules..." commit
  touching submodules/tx3 → a build was triggered
→ Find + watch the Build run → success
→ Find + watch the Deploy run → success
→ curl https://docs.txpipe.io/tx3 → 200
→ grep a heading added by the merged PR → found
  (for a brand-new page, re-check for a few minutes if it 404s/502s)
→ Report: docs live at https://docs.txpipe.io/tx3
```

## Error Handling
- **`gh workflow run` fails — workflow not found:** confirm the filename
  (`update-submodules.yml`) and that you have access to `txpipe/docs`.
- **`gh` not authenticated:** run `gh auth status`; authenticate with
  `gh auth login`.
- **`Update Submodules` succeeds but no commit appears:** `tx3-lang/docs` was
  already current — nothing to publish. Confirm the site is healthy and
  report that, rather than waiting for a build that will never run.
- **`Build` or `Deploy` run fails:** inspect with
  `gh run view <id> --repo txpipe/docs --log-failed`, report the failing
  stage, and do **not** report the docs as published.
- **New page returns `404`/`502` shortly after `Deploy`:** propagation lag
  for a new route — re-check every ~30s for up to ~15 min. Only if it
  persists past that, check the `Deploy` logs and the site's hosting/CDN.
- **Existing page shows stale content after a successful deploy:** likely a
  CDN cache; re-check after a few minutes before escalating.
