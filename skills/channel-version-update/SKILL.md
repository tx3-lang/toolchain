# Channel Version Update Skill

## Purpose
Update toolchain component versions in manifest files by checking GitHub releases and applying necessary version bumps.

## Prerequisites
- GitHub CLI (`gh`) installed and authenticated
- Repository contains `manifest-{channel}.json` files (stable, beta, nightly)
- Each component has `repo_owner` and `repo_name` fields in the manifest

## Context
- **File:** `manifest-{channel}.json`
- **Format:** JSON with `tools` array containing component definitions
- **Version Constraints:** Can use semver ranges (`^x.y.z`) or exact versions (`x.y.z`)

## Procedure

### 1. Identify Components
Read the target manifest file to get:
- Component names
- Current versions
- GitHub repository info (repo_owner, repo_name)

### 2. Query Latest Releases
For each component in the `tools` array, query GitHub API:
```bash
gh api repos/{repo_owner}/{repo_name}/releases/latest | jq -r '.tag_name'
```

### 3. Compare Versions
Create a comparison table showing:
| Component | Repository | Current | Latest | Status |
|-----------|------------|---------|--------|--------|

Mark each as:
- ✅ Up to date
- 🔄 Update available
- ⚠️ Different release track (e.g., RC vs stable)

### 4. Decision Points
Present the table to the user and ask:
- Which components to update?
- How to handle special cases (RC versions, different tracks)
- Whether to maintain semver ranges or switch to exact versions

**Note:** Always confirm with the user before making changes. Different components may have different versioning strategies.

### 5. Update Manifest
Edit `manifest-{channel}.json` to update the `version` field for confirmed components.

### 6. Commit Changes
Commit message format:
```
chore: update versions on {channel} channel

- {component1}: {old_version} → {new_version}
- {component2}: {old_version} → {new_version}
```

### 7. Push to Origin
Push the commit:
```bash
git push origin main
```

## Decision Guidelines

### Which Components to Update?
- Always follow the user's explicit instructions
- Generally update when:
  - Latest version > Current version (semver comparison)
  - Same release track (both stable, both RC, etc.)
  - No breaking changes indicated in release notes (if available)

### Version Constraint Format
- Maintain existing format when updating:
  - If current uses `^x.y.z`, update to `^new_version`
  - If current uses exact `x.y.z`, update to `new_version`
- Use exact versions for pre-release/RC versions
- Use caret (`^`) for stable releases to allow patch updates

### Special Cases
- **RC/Pre-release versions:** Ask the user whether to:
  - Keep current RC version
  - Update to latest RC
  - Switch to latest stable
  
- **Major version changes:** Flag for user review
- **Different versioning schemes:** Document and ask user preference

## Safety Checks
- [ ] Confirm user wants to update before editing files
- [ ] Verify gh CLI returns valid version tags
- [ ] Use proper commit message with detailed change list
- [ ] Push only after successful commit

## Example Workflow
```
User: "Update the stable channel versions"

→ Read manifest-stable.json
→ Check GitHub releases for all 5 components
→ Display comparison table
→ User confirms: update trix and cshell, leave dolos as is
→ Update version fields in manifest
→ Commit: "chore: update versions on stable channel\n\n- trix: ^0.19.7 → ^0.20.0\n- cshell: ^0.13.2 → ^0.14.0"
→ Push to origin main
```

## Error Handling
- If `gh api` fails: Verify gh CLI is installed and authenticated (`gh auth status`)
- If release not found: Component may have no releases yet - document in output
- If manifest file doesn't exist: Check file naming convention (manifest-{channel}.json)
