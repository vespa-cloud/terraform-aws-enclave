# Contributing

This repository uses `locals.template_version` in `main.tf` as the single source of truth for releases. Tags are created automatically from that value on merge to `main`.

SemVer is required: `MAJOR.MINOR.PATCH` (no `v` prefix in the file).

## Versioning and tagging policy

- Regular PRs (most changes):
  - Bump `locals.template_version` in `main.tf`.
  - The new version must be strictly greater than BOTH:
    - The version on `origin/main`, and
    - The latest existing tag (`v<MAJOR.MINOR.PATCH>`).
  - CI (`version-check.yml`) enforces this and will fail if the bump is missing or not higher.

- Minor/no-tag PRs (internal and trivial changes only):
  - Do NOT bump `locals.template_version`.
  - Mark intent by either:
    - Adding the `no-tag` label, or
    - Starting the PR title with `minor` or `[minor` (case-insensitive).
  - CI will fail if `template_version` changes in such PRs.

Examples of minor/no-tag changes:
- Changes in `.github/` or `tools/` that do not affect module behavior
- Minor documentation changes (typo fixes, comment updates, small README tweaks)
- Refactoring that does not alter behavior
- Tests that do not affect module behavior

Examples that REQUIRE a version bump (regular PRs):
- Behavioral changes to Terraform resources, variables, outputs or defaults
- New or removed variables, outputs, or resources
- Any change that users should be aware of when consuming the module, including significant documentation updates

## What happens on merge

- On push to `main`, `.github/workflows/tag-release.yml` creates a tag `v<template_version>` if and only if the version in `main.tf` is strictly greater than the latest existing tag.
- If a PR is minor/no-tag and did not bump the version, no tag will be created.

## Practical checklist

Before requesting review:
- [ ] Is this truly a minor/no-tag PR? If yes, do not bump `template_version`, and mark the PR title/label accordingly.
- [ ] Otherwise (regular PR), bump `locals.template_version` in `main.tf` to a higher SemVer than BOTH `origin/main` and the latest tag.
- [ ] Ensure SemVer format `X.Y.Z` (no `v` prefix) in `main.tf`.
- [ ] Leave `locals.template_version` key name and location unchanged; workflows depend on it.

## Notes for maintainers

- The PR check (`version-check.yml`) reads `main.tf` and verifies bump rules vs `origin/main` and the latest tag.
- The tag workflow (`tag-release.yml`) only looks at `main.tf` on `main` and compares to existing tags. It does not consult PR metadata.
