# Release Workflows Design

## Problem

Releasing a new version of Arrival requires multiple manual steps: build the app, create DMG, create GitHub Release, update appcast.xml, update Homebrew cask, deploy the marketing site. The marketing site also can't be updated independently without running through the release process.

## Solution

Two GitHub Actions workflows:

1. **Release workflow** (`release.yml`) — automates the full release pipeline on tag push
2. **Site deploy workflow** (`deploy-site.yml`) — deploys the marketing site on push to master

## Workflow 1: Release

**Trigger:** Tag push matching `v*`

**Runner:** `macos-latest`

**Steps:**

1. Checkout repo
2. Select Xcode (15.x), resolve SPM dependencies
3. Build app in Release configuration: `xcodebuild -project TrafficMenubar.xcodeproj -scheme TrafficMenubar -configuration Release build`
4. Install `create-dmg` via Homebrew
5. Run `scripts/build-dmg.sh` to create DMG
6. Compute SHA256 of the DMG
7. Create GitHub Release via `gh release create` with DMG attached and SHA256 in release notes
8. Update `arrival-site/appcast.xml` — insert new `<item>` with version, date, download URL, file size
9. Update `homebrew/arrival.rb` — replace version and sha256
10. Commit appcast + cask changes to `master` (bot commit, skip CI to avoid loops)
11. Setup Node, install deps, build Tailwind CSS in `arrival-site/`
12. Deploy `arrival-site/` to GitHub Pages via `actions/deploy-pages`

**Secrets:** Uses default `GITHUB_TOKEN` only. No code signing.

**Xcodegen:** Must run `xcodegen generate` before building since `.xcodeproj` is gitignored.

## Workflow 2: Deploy Site

**Trigger:** Push to `master` with changes in `arrival-site/**`

**Runner:** `ubuntu-latest`

**Steps:**

1. Checkout repo
2. Setup Node, install deps in `arrival-site/`
3. Build Tailwind CSS: `npm run build`
4. Deploy `arrival-site/` to GitHub Pages via `actions/deploy-pages`

## GitHub Pages Configuration

Both workflows deploy to GitHub Pages using the `actions/upload-pages-artifact` + `actions/deploy-pages` pattern. The repo needs Pages enabled with source set to "GitHub Actions" (not branch-based).

## Release Process (User Experience)

To release version 1.1.0:

```bash
# Bump version in project.yml, commit
git tag v1.1.0
git push origin v1.1.0
```

Everything else is automatic: build, DMG, GitHub Release, appcast update, cask update, site deploy.

To update the marketing site without a release: just push changes to `arrival-site/` on master.

## Files to Create

| File | Purpose |
|------|---------|
| `.github/workflows/release.yml` | Full release automation |
| `.github/workflows/deploy-site.yml` | Independent site deployment |

## Files Modified by Release Workflow (at runtime)

| File | Change |
|------|--------|
| `arrival-site/appcast.xml` | New `<item>` block added |
| `homebrew/arrival.rb` | Version and sha256 updated |
