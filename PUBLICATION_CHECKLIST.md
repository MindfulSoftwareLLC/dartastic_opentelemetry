# Publication Checklist

This document outlines the steps to follow when publishing a new version of the OpenTelemetry API for Dart.

## Pre-release Checklist

### Code Quality
- [ ] All tests are passing (`dart test`)
- [ ] Code coverage is at acceptable levels (>90%)
- [ ] No lint warnings (`dart analyze`)
- [ ] Code is properly formatted (`dart format .`)
- [ ] Package scores well on `pana` analysis

### Documentation
- [ ] Documentation is up-to-date with the current version
- [ ] CHANGELOG.md is updated with all notable changes
- [ ] Version numbers are updated in relevant files
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

1. **Prepare Release**
   - [ ] Update version in `pubspec.yaml`
   - [ ] Update CHANGELOG.md with release date and changes
   - [ ] Create a git tag for the version (e.g., `git tag v0.8.0`)
   - [ ] Push the tag to the repository (`git push origin v0.8.0`)

2. **Publish to pub.dev**
   - [ ] Run final `dart pub publish --dry-run` check
   - [ ] Publish with `dart pub publish`
   - [ ] Verify package appears correctly on pub.dev

3. **Post-Release**
   - [ ] Create a GitHub release with release notes
   - [ ] Announce in appropriate channels (if applicable)
   - [ ] Update documentation website (if applicable)
   - [ ] Increment to next development version
   - [ ] Update any dependent packages to use the new version

## Emergency Fixes

If an emergency fix is required for a released version:

1. Create a hotfix branch from the tagged release
2. Make minimal required changes
3. Follow the standard release process but increment the PATCH version
4. Merge the fix back to the main branch if applicable

## CNCF Contribution Considerations

If preparing for CNCF contribution:

- [ ] Ensure all legal requirements are met (license, CLAs, etc.)
- [ ] Review contribution guidelines for the OpenTelemetry organization
- [ ] Prepare documentation specifically required for CNCF review
- [ ] Verify compatibility with other OpenTelemetry implementations
