# Dartastic OpenTelemetry SDK Test Plan

## Overview

This test plan aims to improve the test coverage of the Dartastic OpenTelemetry SDK to at least 85%. The focus is on ensuring the factory pattern is thoroughly tested as the primary entry point for object creation in the SDK.

## Current Issues

Based on the test results, we've identified several key issues:

1. **Counter Implementation**: The primary test failure appears to be in the Counter class, where the reset() method doesn't work properly. The getValue() method returns 0 instead of 42 as expected.

2. **Span Parent Context**: There are failures related to child spans not referencing parent span IDs correctly, with errors like "Child span must reference parent span ID".

3. **Resource Attributes**: Tests involving the resource attributes and tenant_id are failing.

4. **Sampler Implementation**: TraceIdRatioSampler and RateLimitingSampler tests are failing.

5. **Context Serialization**: Tests for context serialization and propagation are failing.

6. **OTLP Exporter Configuration**: URL parsing in OtlpGrpcExporterConfig is not working as expected.

7. **Coverage Tool**: The coverage reporting tool is broken and needs to be fixed.

## Fix Priorities

Let's prioritize the fixes based on their impact:

1. Fix the Counter implementation to properly record and retrieve values
2. Address the parent span context issues
3. Fix Resource attribute handling
4. Repair the Sampler implementations
5. Fix Context serialization and propagation
6. Fix OTLP exporter configuration
7. Fix the coverage reporting tool

## Immediate Fixes

### 1. Counter Implementation Fix

The issue in the Counter implementation appears to be that the test is failing on the reset test. The counter value is not being properly stored or retrieved. 

The fix focuses on:

1. Ensuring the `SumStorage._points` map is correctly storing values by attribute.
2. Verifying the `getValue()` method is correctly retrieving values.
3. Making sure the `reset()` method correctly clears the storage.

The key change in the implementation:
- Using attribute hash codes as keys in the storage map for reliable lookup
- Properly handling null attributes with normalization
- Ensuring correct reset behavior

### 2. Parent Span Context Fix

The error "Child span must reference parent span ID" suggests that when creating child spans, the parent span ID isn't being properly included in the child span's context.

The fix focuses on:
- Properly determining the effective parent context
- Explicitly passing parent span ID to child spans
- Creating span contexts that correctly reference parent spans

### 3. Fix Coverage Tool

The coverage tool script has been fixed to:
1. Properly clean the coverage directory before starting
2. Generate proper lcov.info file
3. Handle the HTML report generation if lcov is available
4. Provide a summary of the coverage

## Test Implementation Plan

The test implementation focuses on these areas:

### 1. Factory Pattern Tests

We've created a dedicated test file for the factory pattern:
- Testing OTelSDKFactory initialization
- Verifying all objects are created through the factory
- Testing that hidden constructors are properly enforced
- Checking resource creation through the factory
- Testing span creation and behavior

### 2. Counter Tests

We've improved counter tests to:
- Test storage of values with different attributes
- Verify reset behavior works correctly
- Test metric collection
- Test addWithMap functionality
- Ensure proper attribute handling

### 3. Span Parent Context Tests

Future tests should focus on:
- Creating child spans with explicit parent spans
- Creating child spans with parent context
- Verifying inheritance of trace and span IDs
- Testing context propagation through the span hierarchy

## Future Work

After implementing these immediate fixes, the next areas to focus on:

1. Resource attribute tests, particularly for tenant_id handling
2. Sampler implementation tests
3. Context serialization and propagation
4. OTLP exporter configuration fixes
5. Additional integration tests between tracing and metrics

## Test Quality Metrics

The goal is to achieve:
1. Line Coverage: >85%
2. Branch Coverage: >80%
3. Method Coverage: >90%
4. Class Coverage: >95%

Each test should include:
1. Happy path
2. Error conditions
3. Edge cases
4. Resource cleanup
5. Async behavior
6. State management
