# Publication Checklist

This document outlines the steps to follow when publishing a new version of the OpenTelemetry API for Dart.

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
- [ ] Examples demonstrate current SDK usage and best practices

### Compatibility
- [ ] Breaking changes are documented and follow versioning policy
- [ ] Compatibility with the OpenTelemetry specification is verified
- [ ] Compatibility with OpenTelemetry API for Dart is maintained
- [ ] Platform-specific compatibility is tested (VM, Web, Flutter)

### Continuous Integration
- [ ] All CI checks pass on the main branch
- [ ] All dependencies are up-to-date
- [ ] Integration with OpenTelemetry Collector is tested

## Release Process

This repo follows the Flutter / Dart team's `-wip` convention. The
working `pubspec.yaml` version always ends in `-wip` and CHANGELOG
entries land under a `## [X.Y.Z-wip]` section header during
development. `tool/release.sh` performs the release.

1. **Prepare Release**
   - [ ] Working tree is clean and on `main` (or the release branch).
   - [ ] CHANGELOG `## [X.Y.Z-wip]` section reflects everything in this release.
   - [ ] `dart pub publish --dry-run` is clean.

2. **Cut the release** — run `tool/release.sh`. The script:
   - Strips `-wip` from `pubspec.yaml` and the CHANGELOG header, dates
     the section.
   - Runs `dart pub get`, `dart analyze`, `dart test`.
   - Commits as `Release X.Y.Z` and tags `vX.Y.Z`.
   - Bumps `pubspec.yaml` to next `-wip` (auto-bumps the rightmost
     numeric component, or pass `--next X.Y.Z` to override).
   - Inserts a fresh `## [X.Y.Z-wip]` CHANGELOG section.
   - Commits as `Bump to X.Y.Z-wip`.
   - Pass `--yes` for non-interactive runs.

3. **Push and publish**
   - [ ] `git push origin HEAD vX.Y.Z`
   - [ ] `dart pub publish`
   - [ ] Verify package appears correctly on pub.dev

4. **Post-Release**
   - [ ] Create a GitHub release with release notes (use the
         CHANGELOG entry as the body)
   - [ ] Announce in appropriate channels (if applicable)
   - [ ] Update documentation website (if applicable)
   - [ ] Update any dependent packages to use the new version

## Emergency Fixes

If an emergency fix is required for a released version:

1. Create a hotfix branch from the tagged release.
2. Set `pubspec.yaml` version to the patch-bump form ending in `-wip`
   (e.g. for a `v1.0.0` hotfix, use `1.0.1-wip`).
3. Add the fix and a `## [1.0.1-wip]` CHANGELOG section.
4. Run `tool/release.sh` to cut `1.0.1`.
5. Cherry-pick the fix back to `main` if applicable. If main was on a
   newer wip already, just keep that wip number — don't downgrade.

## CNCF Contribution Considerations

If preparing for CNCF contribution:

- [ ] Ensure all legal requirements are met (license, CLAs, etc.)
- [ ] Review contribution guidelines for the OpenTelemetry organization
- [ ] Prepare documentation specifically required for CNCF review
- [ ] Verify compatibility with other OpenTelemetry implementations
