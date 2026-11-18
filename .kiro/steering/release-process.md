---
inclusion: auto
description: Enforces semantic versioning and release checklist before any git commit
---

# Release Process

This project uses semantic versioning. Do NOT make ad-hoc git commits. Every commit must be a proper versioned release.

## Before ANY git commit, follow this checklist

1. **Test fully** — run the app, run tests if they exist, verify behavior
2. **Update `CHANGELOG.md`** — add a new section with bullet points for every change
3. **Bump `VERSION`** — single source of truth for the version number
4. **Commit** — `git add -A && git commit -m "vX.Y.Z: short description"`
5. **Tag** — `git tag vX.Y.Z`
6. **Push** — `git push && git push --tags`
7. **Deploy** — `./deploy.sh` (when applicable)

## Version numbering (semver)

- **Patch** (x.y.Z): bug fixes, typos, comment improvements
- **Minor** (x.Y.0): new features, refactoring, new config
- **Major** (X.0.0): breaking changes, major rewrites

## Deploy scripts

- `./deploy.sh` — Lightweight: git pull + restart service (fast, routine deploys)
- `./full-redeploy.sh` — Full: Ansible role or complete rebuild (fresh installs, dependency changes)

## Do NOT

- Make commits without version numbers
- Deploy before committing (deploy is the last step, after push)
- Work on a `develop` branch (use `main` directly)
