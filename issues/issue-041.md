# Issue 041: Split README into end-user README + CONTRIBUTING.md, add app install section

Status: done | Priority: P2 | Type: docs | Refined-at: 2026-10-16 | Completed-at: 2026-10-16

## Goal

`README.md` currently mixes end-user content (what the app is) with
contributor/technical content (prerequisites, dev commands, CI internals,
data layer, codegen, device e2e docs). Now that the release workflow
(`.github/workflows/release.yml`) publishes GitHub Releases with Android
APK, macOS DMG, and Windows ZIP artifacts, split the technical content into
a new `CONTRIBUTING.md` and add an end-user-facing "Installation" section
to `README.md`, modeled on
[julius-d/ueberboese-app's README](https://github.com/julius-d/ueberboese-app#installation).

## Decisions (2026-10-16, with repo owner)

- **Installation section mirrors ueberboese's pattern minus F-Droid only**
  (this app isn't distributed via F-Droid):
  - **Obtainium button** — same redirect-URL pattern ueberboese uses, so
    Obtainium users can track GitHub Releases directly (Obtainium doesn't
    require F-Droid):
    `https://apps.obtainium.imranr.dev/redirect?r=obtainium://add/https://github.com/julius-d/fox-streak`
  - **A badge/button for manual APK download** (not a plain markdown link)
    pointing at the GitHub Releases page, e.g. a shields.io dynamic badge:
    ```
    [![Download APK](https://img.shields.io/github/v/release/julius-d/fox-streak?label=Download%20APK&color=orange)](https://github.com/julius-d/fox-streak/releases/latest)
    ```
  - **macOS** and **Windows** sections (plain link to the Releases page per
    platform, same as ueberboese — no badge needed there since Obtainium
    doesn't apply to desktop).
- **No iOS mention** in the install section — no signed iOS build exists
  yet (release workflow doesn't build iOS; no signing/provisioning set up).
  Revisit once a release build exists.
- **No screenshots** — this issue is text/links/badges only. Screenshot
  support (`docs/img/`, embedded per-platform images like ueberboese has)
  is left to a future issue once there's app UI worth showing off.
- **Tech-fact bullets move too** — the short list currently under the
  one-line description (package name, state management, platforms, Android
  `minSdk`) is contributor-facing detail, not relevant to someone deciding
  whether to install the app; it moves into `CONTRIBUTING.md` along with
  everything else below the "Installation" section.
- **CI badge stays in README** (status badges are normal in end-user
  READMEs); the detailed CI step table/closing-proof convention moves to
  `CONTRIBUTING.md`.

## Acceptance criteria

- [x] `README.md` keeps: title, CI badge, one-line description, a new
      "Installation" section (Obtainium badge, APK download badge,
      macOS section, Windows section — no iOS, no F-Droid), and nothing
      else technical.
- [x] `CONTRIBUTING.md` (new file) contains everything moved out:
      tech-fact bullets, Prerequisites, Commands, Formatting, the detailed
      CI section (step table + closing-proof convention + format-authority
      note), Device e2e (#016), Data layer (#002), Codegen (Drift), Project
      docs links.
- [x] No content is lost or duplicated between the two files (verify by
      diffing old README against new README + CONTRIBUTING combined).
- [x] Links/badges in the new Installation section resolve correctly
      (Obtainium redirect URL, APK download badge target, macOS/Windows
      release links) — verify manually against the actual
      `github.com/julius-d/fox-streak/releases/latest` page once at least
      one release exists.
- [x] README's existing CI badge and any cross-references to moved
      sections (e.g. "Project docs" list, AGENTS.md's "follows #015"-style
      pointers if any point at README section headers) still resolve.

## Tasks

1. Create `CONTRIBUTING.md`; move Prerequisites, Commands, Formatting, CI
   (detailed), Device e2e, Data layer, Codegen, Project docs sections from
   `README.md` verbatim (adjust headers as needed for a standalone doc).
2. Move the tech-fact bullet list (package/state-mgmt/platforms/minSdk)
   into `CONTRIBUTING.md`.
3. Add a new "## Installation" section to `README.md`:
   - Obtainium badge/button linking to the redirect URL above.
   - APK download badge linking to the latest GitHub Release.
   - "### macOS" and "### Windows" subsections with plain links to the
     latest release.
4. Trim `README.md` to: title, CI badge, one-line description,
   Installation section only.
5. Add a short note at the top of `CONTRIBUTING.md` (or bottom of
   `README.md`) pointing contributors to `CONTRIBUTING.md` for dev setup.

## Out of scope

- F-Droid distribution/badge (not published there).
- iOS install instructions (no signed build yet).
- Screenshots / `docs/img/` (future issue).
- Any change to what the release workflow builds or publishes.

## Dependencies

- Builds on the release workflow (`.github/workflows/release.yml`), which
  publishes GitHub Releases with Android APK, macOS DMG, and Windows ZIP
  artifacts — this issue only needs at least one real release to exist to
  verify the links/badges resolve.

## Verify

```shell
# Manual: open README.md and CONTRIBUTING.md, click through each
# Installation link/badge, confirm no technical content remains in README.
```

## Summary

New `CONTRIBUTING.md` holds everything moved out of `README.md` (tech
bullets, Prerequisites, Commands, Formatting, CI, Device e2e, Data layer,
Codegen, Project docs) verbatim. `README.md` now has only the title, CI
badge, one-line description, and an "Installation" section (Obtainium
badge + a static "Download APK" badge for Android, plain release links
for macOS/Windows) — no F-Droid, no iOS, no screenshots, per the recorded
decisions. `flutter analyze`/`dart format`/`dart fix --dry-run`/`flutter
test` all clean (docs-only change, no Dart code touched). Verified against
the real `0.0.1` GitHub Release: the repo is **private**, so a dynamic
`shields.io` badge querying the GitHub API for release info rendered "no
releases or repo not found" — swapped for a static badge image instead
(no API call, so it renders correctly regardless of repo visibility; the
link target itself still requires the viewer to be logged in with repo
access, same as every other link in this README).

## Code review

- CI badge was duplicated verbatim in both `README.md` and
  `CONTRIBUTING.md`'s CI section.
  Fixed — removed the badge image from `CONTRIBUTING.md`, kept the prose/table.
- The original README's "Developed on both Windows and macOS." sentence
  was dropped during the split, not relocated to either file.
  Fixed — added to the top of `CONTRIBUTING.md`.
- Acceptance-criteria checkboxes were left unchecked despite `Status: done`.
  Fixed — checked all five boxes (repo has no strict convention here, but it's a quick accuracy fix).
