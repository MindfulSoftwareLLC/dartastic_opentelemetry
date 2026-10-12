# Publication Checklist

This document outlines the steps to follow when publishing a new version of the OpenTelemetry SDK for Dart. Each
release is two publications: the `1.1.0-beta.N` prerelease, then its stable-channel republication as `0.N.0` (see
[Stable-Channel Backport](#stable-channel-backport)).

## Pre-release Checklist

### Code Quality
- [ ] All tests are passing (`./tool/test.sh`)
- [ ] Code coverage is >90% (`./tool/coverage.sh`)
- [ ] No lint warnings (`dart analyze`)
- [ ] Code is properly formatted (`dart format .`)
- [ ] Package scores well on `pana` analysis

### Documentation
- [ ] Documentation is up-to-date with the current version
- [ ] CHANGELOG.md entries for this release land under the `## [X.Y.Z-wip]` section
- [ ] `pubspec.yaml` version still ends in `-wip` (the release script strips it)
- [ ] If the release will be backported, a `## [0.N.0] - unreleased` section sits directly below the `-wip` section
      (see [Stable-Channel Backport](#stable-channel-backport))
- [ ] Examples demonstrate current SDK usage and best practices

### Compatibility
- [ ] Breaking changes are documented and follow versioning policy
- [ ] Compatibility with the OpenTelemetry specification is verified
- [ ] Compatibility with OpenTelemetry API for Dart is maintained
- [ ] A dependency on a prerelease of `dartastic_opentelemetry_api` is bounded to that one prerelease,
      `'>=1.0.0-rc.N <1.0.0-rc.N+1'`, never a caret. `^1.0.0-rc.N` admits every later rc and 1.x, and a published
      version cannot be retracted after 7 days
- [ ] Platform-specific compatibility is tested (VM, Web, Flutter)

### Continuous Integration
- [ ] All CI checks pass on the main branch
- [ ] All dependencies are up-to-date
- [ ] Integration with OpenTelemetry Collector is tested

## Release Process

This repo follows the Flutter / Dart team's `-wip` convention. The
working `pubspec.yaml` version always ends in `-wip` and CHANGELOG
entries land under a `## [X.Y.Z-wip]` section header during
development. `dart tool/release.dart` performs the release.

1. **Prepare Release**
   - [ ] Working tree is clean and on `main` (or the release branch).
   - [ ] CHANGELOG `## [X.Y.Z-wip]` section reflects everything in this release.
   - [ ] `dart pub publish --dry-run` is clean.

2. **Cut and publish the release** — run `dart tool/release.dart`. The script:
   - Strips `-wip` from `pubspec.yaml` and the CHANGELOG header, dates
     the section.
   - Runs `dart pub get`, `dart analyze`, `dart test`. Note: SDK tests
     normally rely on a live OTel collector via `tool/test.sh`. Run
     that beforehand to verify, then pass `--skip-tests` to the release
     script if the collectorless `dart test` fails.
   - Commits as `Release X.Y.Z` and tags `vX.Y.Z`.
   - Bumps `pubspec.yaml` to next `-wip` (auto-bumps the rightmost
     numeric component, or pass `--next X.Y.Z` to override).
   - Inserts a fresh `## [X.Y.Z-wip]` CHANGELOG section.
   - Commits as `Bump to X.Y.Z-wip`.
   - Checks out the `vX.Y.Z` tag and runs `dart pub publish` so the
     working tree being published actually matches the release version.
     pub.dev's own `Do you want to publish ...?` prompt is the gate.
   - Returns the working tree to your branch on success.
   - Pushes the branch and the `vX.Y.Z` tag to origin, then creates the
     GitHub release from the CHANGELOG section (marked prerelease for a
     `-beta` version) with the `gh` CLI.
   - Flags: `--yes` for non-interactive confirm, `--no-publish` to
     stop after the local commits, `--skip-tests` to skip `dart test`,
     `--next X.Y.Z` to override the bumped dev version,
     `--no-github-release` to skip the GitHub release.
   - If the script is interrupted before it commits, nothing is published:
     `git checkout -- CHANGELOG.md README.md lib/src/version.dart pubspec.yaml`
     restores the `-wip` state.

3. **Verify**
   - [ ] The package appears correctly on pub.dev
   - [ ] The `vX.Y.Z` tag and GitHub release exist. If the script warned
         that the push or `gh` failed, run `git push origin HEAD vX.Y.Z`
         and create the release by hand.

4. **Backport** to the stable channel, see
   [Stable-Channel Backport](#stable-channel-backport).

5. **Post-Release**
   - [ ] Announce in appropriate channels (if applicable)
   - [ ] Update documentation website (if applicable)
   - [ ] Update any dependent packages to use the new version

## Stable-Channel Backport

Users who have not opted into prereleases get the fixes through the `0.x`
stable channel. Each `0.N.0` release is a beta's code with a stable version
stamp, not separate development: `0.11.0` republishes `1.1.0-beta.15`, and
`0.12.0` republishes `1.1.0-beta.17`. A backport whose betas include a
breaking change bumps the minor version; one with only fixes may be a patch.
`dart tool/backport_release.dart` performs it, after `tool/release.dart` has
published the beta.

1. **Prepare**, on `main` before cutting the beta (or after, before the backport)
   - [ ] The API has published its matching stable republication (e.g.
         `dartastic_opentelemetry_api` `0.12.0` republishes `1.0.0-rc.4`).
         The backport depends on it with a caret, `^0.N.0`.
   - [ ] CHANGELOG has a `## [0.N.0] - unreleased` section directly below
         the beta it republishes. It names the beta and the API constraint
         and points to the beta sections it carries; see `## [0.11.0]` or
         `## [0.12.0]`. The script fails early if the section is missing.
   - [ ] Working tree is clean and `git fetch --tags` has run, so the beta's
         tag is local.

2. **Cut and publish**:

   ```
   dart tool/backport_release.dart --version 0.N.0 --from v1.1.0-beta.M --api-constraint '^0.N.0'
   ```

   The script:
   - Checks out the beta's tag detached, so what is published is the beta's
     tree, not your branch.
   - Sets `version:` to `0.N.0` and rewrites the `dartastic_opentelemetry_api`
     constraint from the prerelease range to `--api-constraint`. Without
     that flag it reuses the previous `0.x` tag's constraint, which is wrong
     whenever the API has cut a new stable release, so pass it.
   - Updates the `dartastic_opentelemetry: ^...` line in README.md and dates
     the `## [0.N.0]` header.
   - Runs `dart pub get`, `dart analyze` and the tests (`--skip-tests` to skip).
   - Commits `Release 0.N.0 — stable-channel republication of 1.1.0-beta.M`
     and tags `v0.N.0`. That commit is reachable only from the tag; it is
     never merged.
   - Runs `dart pub publish` (pub.dev's prompt is the gate).
   - Returns to your branch, pushes the tag, creates the GitHub release from
     the CHANGELOG section, and commits the dated `## [0.N.0]` header on your
     branch so `main`'s CHANGELOG records the release. Push that commit.
   - Flags: `--from` defaults to the latest beta tag; `--yes`, `--no-publish`,
     `--skip-tests`, `--no-github-release`, and `--no-sync-changelog` to leave
     the branch's CHANGELOG alone.

3. **Verify**
   - [ ] `0.N.0` is on pub.dev and resolves against `dartastic_opentelemetry_api: ^0.N.0`
   - [ ] The `v0.N.0` tag and GitHub release exist
   - [ ] `main` carries the dated `## [0.N.0]` header

## Emergency Fixes

If an emergency fix is required for a released version:

1. Create a hotfix branch from the tagged release.
2. Set `pubspec.yaml` version to the patch-bump form ending in `-wip`
   (e.g. for a `v1.0.0` hotfix, use `1.0.1-wip`).
3. Add the fix and a `## [1.0.1-wip]` CHANGELOG section.
4. Run `dart tool/release.dart` to cut `1.0.1`.
5. Cherry-pick the fix back to `main` if applicable. If main was on a
   newer wip already, just keep that wip number — don't downgrade.

## CNCF Contribution Considerations

If preparing for CNCF contribution:

- [ ] Ensure all legal requirements are met (license, CLAs, etc.)
- [ ] Review contribution guidelines for the OpenTelemetry organization
- [ ] Prepare documentation specifically required for CNCF review
- [ ] Verify compatibility with other OpenTelemetry implementations
