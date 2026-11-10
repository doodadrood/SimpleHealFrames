# SimpleHeal Release Runbook (`RELEASE.md`)

This runbook defines the automated release workflow for **SimpleHeal** (`SimpleHealFrames`), ensuring the headless LuaJIT test suite passes, release notes and versioning are updated, and the GitHub Actions pipeline packages and deploys the addon to **GitHub Releases** and **CurseForge (Project ID: `1786366`)**.

---

## Automated Release Checklist

### Step 1: Run the Bytecode & Headless Test Suite Gate
Always verify syntax and all unit/taint tests before cutting a release:

```bash
luajit -bl SimpleHeal.lua /dev/null
luajit tests/test_simpleheal.lua
```
*Abort immediately if any test fails or exits with a non-zero status.*

### Step 2: Update Versioning & Release Notes
1.Determine the next semantic version tag (e.g. `v1.1.5`):
```bash
git tag --sort=-v:refname | head -n 5
```
2. Prepend the new version section to `CHANGELOG.md` (used automatically by `BigWigsMods/packager` via `.pkgmeta`'s `manual-changelog` configuration to populate CurseForge and GitHub Release notes).
3. Note: `SimpleHeal.toc` uses `## Version: @project-version@`, which `BigWigsMods/packager` automatically replaces with the exact Git tag string (e.g. `v1.1.5`) inside the packaged zip archive.

### Step 3: Commit & Push to `main`
```bash
git add -A
git commit -m "Release vX.Y.Z"
git push origin main
```

### Step 4: Cut & Push the Semantic Version Tag
Pushing a `v*` annotated tag triggers `.github/workflows/release.yml`, which:
1. Runs the LuaJIT test gate on `ubuntu-latest`.
2. Packages `SimpleHeal/` (excluding `tests/`, `.github/`, `.agents/`, and repo metadata).
3. Uploads the release archive and `CHANGELOG.md` notes to **GitHub Releases** and **CurseForge (`1786366`)**.

```bash
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin vX.Y.Z
```

### Step 5: Verify Workflow Status
```bash
gh run list --limit 3
gh run watch
```
