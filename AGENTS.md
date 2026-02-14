# Agent Skills Index

This repository contains skill definitions that guide automated agents in performing common maintenance tasks.

## Available Skills

| Skill | Description | Location |
|-------|-------------|----------|
| `channel-version-update` | Update toolchain component versions by checking GitHub releases and updating manifest files | `skills/channel-version-update/SKILL.md` |

## Using Skills

When instructed to perform a task covered by a skill, follow the procedure documented in the corresponding SKILL.md file.

### Skill Format
Each skill is documented in `skills/{skill-name}/SKILL.md` with:
- **Purpose:** What the skill accomplishes
- **Prerequisites:** Required tools and setup
- **Context:** Files, formats, and environment expectations
- **Procedure:** Step-by-step execution guide
- **Decision Guidelines:** How to handle common decisions
- **Safety Checks:** Verification steps before/during execution

---

*Last updated: 2026-02-14*
