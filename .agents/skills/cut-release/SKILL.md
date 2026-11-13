---
name: cut-release
description: >-
  Use this skill whenever the user asks to "cut a release", bump the version,
  or deploy an update of SimpleHeal (SimpleHealFrames) to GitHub Releases and
  CurseForge.
---

# SimpleHeal Cut-Release Skill

## Step-by-Step Procedure

1. **Verify Working Tree & Line Endings**
   - Check `git status` and review pending edits.
   - Ensure source files keep LF line endings (`.gitattributes` enforces `* text=auto eol=lf`).
   - Stage and commit pending addon changes using Conventional Commits (e.g., `fix: ...`, `feat: ...`, `chore: ...`) before cutting the release commit.

2. **Run the LuaJIT Test Gate**
   Always use `luajit` (never `lua`):
   ```bash
   luajit -bl SimpleHeal.lua /dev/null && luajit tests/test_simpleheal.lua
   ```
   Abort immediately if either command exits non-zero.

3. **Determine Next Semantic Version & Update `CHANGELOG.md`**
   - List existing tags:
     ```bash
     git tag --sort=-v:refname | head -n 5
     ```
   - Choose the next semantic version `vX.Y.Z` (e.g., `v1.1.7` -> `v1.1.8`).
   - Prepend a `## vX.Y.Z (YYYY-MM-DD)` entry to `CHANGELOG.md` (consumed by `BigWigsMods/packager` via `.pkgmeta`'s `manual-changelog`).
   - Keep `## Version: @project-version@` and `## X-Curse-Project-ID: 1786366` intact in `SimpleHeal.toc` so `BigWigsMods/packager@v2` substitutes the release tag automatically during packaging.

4. **Commit, Tag, and Push**
   - Commit the release update, create the annotated tag, and verify remote push access:
     ```bash
     git add CHANGELOG.md
     git commit -m "chore: release vX.Y.Z"
     git tag -a vX.Y.Z -m "Release vX.Y.Z"
     git push --dry-run origin main --tags
     ```
   - Push to `origin main` with tags (note: `git push` requires unsandboxed network access in Antigravity — try sandboxed first, then request unsandboxed execution if DNS/network blocks it; note `gh` may be installed via Flatpak rather than `$PATH`):
     ```bash
     git push origin main --tags
     ```

5. **Verify CI/CD Deployment**
   - Confirm `.github/workflows/release.yml` (`Test, Package & Release`) passes on the `vX.Y.Z` tag push and deploys to GitHub Releases and CurseForge (project ID `1786366`, requires `CF_API_KEY` secret in GitHub repo settings).
