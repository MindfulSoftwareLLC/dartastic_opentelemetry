# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.2] - 2025-10-11
- Using INFO OTel log from dartastic_opentelemetry API to 0.8.8.

## [0.9.1] - 2025-10-04
- Bumped API to 0.8.8 to fix logging.

## [0.9.0] - 2025-10-04
- Added support for `OTEL_EXPORTER_OTLP_HEADERS` for http and grpc exporters for trace and metrics
- Added support for all other exporter env vars
- Documented OTEL_* env var usage, added grafana examples
- Certificates env vars may not work yet tests skipped.  

## [0.8.7] - 2025-09-29
- Upgraded to api 0.8.7. Upgraded all dependencies including grpc to 4.1
- Respected all OTel env vars when no explicit values are specified, uses OTEL_CONSOLE_EXPORTER 
- Fixed default export, uses http/protobuf by default, not grpc
- Fixed issue with creation of the grpc exporter
- ConsoleExporter now only created on env vars or explicity
- Minor, doc, dart format, improved .gitignore, removed generated mistakenly committed 

## [0.8.6] - 2025-09-24
- Minor, cleaning, format, doc.

## [0.8.5] - 2025-06-14
- prep for wondrous otel demo, upgrade to api 0.8.3, span toString 

## [0.8.4] - 2025-06-06
- fix: Issue #3 - Fixed Metric generics for Histogram.
- chore: All 445 tests pass, 12 ignored, 0 fail, no crashes, thoroughly applied OTel.shutdown in test tearDowns.

## [0.8.3] - 2025-06-04
- fix: Issue 4, lack of span export

## [0.8.2] - 2025-05-06
- README.md updates

## [0.8.1] - 2025-05-06
- README.md updates

## [0.8.0] - 2025-05-01

### Added
- Initial public release of the OpenTelemetry SDK for Dart
- Complete implementation of the OpenTelemetry API
- Full tracing implementation with span processors
- Multiple exporters: OTLP (gRPC and HTTP), Console, Zipkin
- Resource providers for service information
- Sampler implementations: AlwaysOn, AlwaysOff, TraceIdRatio, ParentBased
- Context propagation: W3C Trace Context, W3C Baggage, Composite
- Batch processing with configurable parameters
- Comprehensive test suite
- Complete examples for various use cases

### Compatibility
- Implements OpenTelemetry SDK specification v1.0.0-rc3
- Requires opentelemetry_api: ^0.8.0
- Compatible with OpenTelemetry Protocol (OTLP) v0.18.0
