# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
