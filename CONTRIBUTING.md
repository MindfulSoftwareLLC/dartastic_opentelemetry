# Contributing to OpenTelemetry SDK for Dart

Thank you for your interest in contributing to the OpenTelemetry SDK for Dart! This document provides guidelines and instructions for contributing to this project.

## Code of Conduct

This project follows the [CNCF Code of Conduct](https://github.com/cncf/foundation/blob/main/code-of-conduct.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to the project maintainers.

## Ways to Contribute

There are many ways to contribute to this project:

- **Code contributions**: Implement new features or fix bugs
- **Documentation**: Improve or extend documentation
- **Bug reports**: Submit detailed bug reports
- **Feature requests**: Suggest new features or improvements
- **Reviews**: Review pull requests from other contributors
- **Discussions**: Participate in discussions and help shape the project

## Getting Started

### Setting Up Development Environment

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/opentelemetry_api.git
   cd opentelemetry_api
   ```
3. Add the upstream repository:
   ```bash
   git remote add upstream https://github.com/MindfulSoftwareLLC/opentelemetry_api.git
   ```
4. Install dependencies:
   ```bash
   dart pub get
   ```

### Development Workflow

1. Create a new branch for your work:
   ```bash
   git checkout -b feature/your-feature-name
   ```
2. Make your changes
3. Run tests to ensure everything works:
   ```bash
   ./tool/test.sh
   ```
   Why not just `dart test`? The unit tests uses a real otel collector for robustness.  
   The test.sh script downloads the otel collector for the currecnt platform if it hasn't been downloaded before
4. Run the analyzer:
   ```bash
   dart analyze
   ```
5. Format your code:
   ```bash
   dart format .
   ```
6. Commit your changes with a descriptive commit message:
   ```bash
   git commit -m "Add feature: description of your changes"
   ```
7. Push your branch to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```
8. Create a pull request to the main repository

## Pull Request Process

1. Update the README.md or other documentation with details of changes if appropriate
2. Update the CHANGELOG.md with a description of your changes
3. The PR should work with the latest version of Dart and be compatible with all supported platforms
4. The PR will be merged once it receives approval from project maintainers

## Coding Standards

### Code Style

This project follows the official [Dart style guide](https://dart.dev/guides/language/effective-dart/style) and uses the standard Dart formatting tool (`dart format`).

### Linting Rules

We use the recommended Dart linting rules. Always run `dart analyze` before submitting a PR to ensure your code follows these rules.

### Testing

All new code should be covered by tests. We use the `test` package for writing and running tests.

- All tests should be in the `test` directory
- Test files should end with `_test.dart`
- Run tests with `./tool/test.sh` and `./tool/test_env_vars.sh`

### Coverage
Run `./tool/coverage.sh` to ensure new/changed code has test coverage.
Coverage required `lcov`. Which can be installed with `brew install lcov` (Mac) or `sudo apt-get install -y lcov` (Linux)

### Documentation

- All public APIs must have dartdoc comments
- Comments should explain "why" not just "what"
- Example usage is encouraged for complex functionality

## Specification Compliance

Since this project implements the OpenTelemetry API specification:

1. All implementations must strictly follow the [OpenTelemetry specification](https://opentelemetry.io/docs/specs/otel/)
2. Any deviations from the specification must be clearly documented and justified
3. Follow the semantic conventions defined by OpenTelemetry

## Commit Messages

Write clear, concise commit messages that explain the changes you've made. Follow these guidelines:

- Use the present tense ("Add feature" not "Added feature")
- Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit the first line to 72 characters or less
- Reference issues and pull requests liberally after the first line

## Issue Process

### Reporting Bugs

When reporting bugs, please include:

- A clear, descriptive title
- A detailed description of the issue
- Steps to reproduce the problem
- Expected behavior and actual behavior
- Your environment (Dart version, platform, etc.)
- If possible, a minimal code example that demonstrates the issue

### Feature Requests

Feature requests are welcome. Please provide:

- A clear, descriptive title
- A detailed description of the proposed feature
- An explanation of why this feature would be useful
- Example use cases
- If possible, outline how the feature might be implemented

## Release Process

The release process is handled by project maintainers. If you're a maintainer, follow these steps:

1. Update version in `pubspec.yaml`
2. Update CHANGELOG.md with all changes since the last release
3. Create a release commit
4. Tag the release commit with the version number (e.g., `v1.0.0`)
5. Push the commit and tag to the repository
6. Publish to pub.dev:
   ```bash
   dart pub publish
   ```

## Communication

- GitHub Issues: For bug reports, feature requests, and general discussions
- Pull Requests: For code contributions and reviews

## License

By contributing to this project, you agree that your contributions will be licensed under the project's [Apache 2.0 License](LICENSE).

## Questions?

If you have any questions about contributing, please open an issue or contact the project maintainers directly.

Thank you for contributing to the OpenTelemetry API for Dart!
