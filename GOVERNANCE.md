# Governance Model for OpenTelemetry SDK for Dart

This document outlines the governance model for the OpenTelemetry SDK for Dart project, which aims to align with the Cloud Native Computing Foundation (CNCF) OpenTelemetry project's governance structure while being adapted for the specific needs of this implementation.

## Project Maintainers

The project is currently maintained by:

- Michael Bushe ([@michaelbushe](https://github.com/michaelbushe)) - Lead Maintainer

Maintainers are responsible for:

- Reviewing and merging pull requests
- Triaging issues and managing the issue tracker
- Ensuring code quality and adherence to OpenTelemetry specifications
- Managing releases
- Handling security issues
- Making decisions about the project's direction

## Decision Making Process

Decisions about the project are made through consensus among maintainers. For significant changes that affect the SDK compatibility or project direction:

1. A proposal should be submitted as a GitHub issue
2. The proposal will be discussed publicly
3. Maintainers will seek consensus
4. If consensus cannot be reached, a vote will be taken among maintainers, with a simple majority required for approval

## Becoming a Maintainer

New maintainers are added through the following process:

1. Demonstrate sustained, high-quality contributions to the project
2. Show understanding of the project's goals and OpenTelemetry specifications
3. Be nominated by an existing maintainer
4. Gain approval from a majority of existing maintainers

## Contributions

We welcome contributions from all members of the community. Please refer to the [CONTRIBUTING.md](CONTRIBUTING.md) file for guidelines on how to contribute.

## Code of Conduct

All participants in the project are expected to follow the CNCF Code of Conduct available at [https://github.com/cncf/foundation/blob/main/code-of-conduct.md](https://github.com/cncf/foundation/blob/main/code-of-conduct.md).

## Relationship with OpenTelemetry Project

This project aims to be a compliant implementation of the OpenTelemetry specification for Dart. While we maintain our own governance for this specific implementation, we:

- Follow the OpenTelemetry specification
- Implement the [OpenTelemetry SDK for Dart](https://pub.dev/packages/dartastic_opentelemetry)
- Seek alignment with the broader OpenTelemetry community
- Prioritize interoperability with other OpenTelemetry implementations
- Support compatibility with the OpenTelemetry Collector
- Participate in relevant OpenTelemetry SIGs (Special Interest Groups)

## Changes to Governance

Changes to this governance document should be proposed via pull request and require approval from a majority of maintainers.

## CNCF Alignment

As part of our goal to potentially contribute this project to the CNCF OpenTelemetry organization, we align with CNCF governance principles:

- Open Source (Apache 2.0 license)
- Open Governance
- Open Contributions
- Open Technical Decisions

## Security Issues

Security vulnerabilities should be reported privately to the maintainers. See [SECURITY.md](SECURITY.md) for details.

## Versioning and Stability

The project follows semantic versioning and provides stability guarantees as documented in [VERSIONING.md](VERSIONING.md).

## Relation to Other Dart OpenTelemetry Projects

This SDK implements the [OpenTelemetry API for Dart](https://pub.dev/packages/opentelemetry_api) and provides a complete implementation of the OpenTelemetry specification. It is designed to be:

- Compatible with the OpenTelemetry API for Dart
- Interoperable with the OpenTelemetry Collector
- Usable in various Dart environments (VM, Web, Flutter)

This governance model applies specifically to the SDK implementation, while the API has its own governance document.
