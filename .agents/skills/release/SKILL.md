---
name: release
description: >-
  Automated release workflow for SimpleHeal (SimpleHealFrames). Runs the LuaJIT
  syntax check and headless test suite, updates CHANGELOG.md and semantic
  versioning, commits and pushes to main, and tags and pushes a new release to
  GitHub to trigger the CurseForge (1786366) and GitHub Releases CI/CD pipeline.
---

# SimpleHeal Release Skill

Use this skill whenever the user asks to cut a release, bump the version, or deploy an update of `SimpleHeal` to GitHub Releases and CurseForge.

## Step-by-Step Procedure

1. **Run the Automated Test Gate**
   Execute the LuaJIT bytecode syntax check and headless test suite:
   ```bash
   luajit -bl SimpleHeal.lua /dev/null && luajit tests/test_simpleheal.lua
   ```
   If any test fails, fix the issue before proceeding. Never tag a broken build.

2. **Determine the Next Semantic Version & Update `CHANGELOG.md`**
   - Check the latest git tag:
     ```bash
     git tag --sort=-v:refname | head -n 5
     ```
   - Increment the patch/minor/major version as requested (e.g., `v1.1.5` -> `v1.1.6`).
   - Update `CHANGELOG.md` with a summary of changes under the new version heading (`## vX.Y.Z (YYYY-MM-DD)`).
   - Ensure `SimpleHeal.toc` retains `## Version: @project-version@` and `## X-Curse-Project-ID: 1786366`.

3. **Stage, Commit, and Push `main`**
   ```bash
   git add -A
   git commit -m "Release vX.Y.Z"
   git push origin main
   ```

4. **Create and Push the Annotated Release Tag**
   ```bash
   git tag -a vX.Y.Z -m "Release vX.Y.Z"
   git push origin vX.Y.Z
   ```
   Pushing the `v*` tag triggers `.github/workflows/release.yml` to run the CI test gate and publish the clean `SimpleHeal/` zip to GitHub Releases and CurseForge (`1786366`).
