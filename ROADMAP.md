# Dartastic OpenTelemetry SDK Road Map 

## Completeness

### Signals

- Logs (and move recently deprecated trace SpanEvent to Logs as spec hardens)
- Profile, when the spec is ready

### Context Propagation

- Across network calls
  - http package, internal
  - a separate package for Dio 
  - A separate package for other http 3rd party packages

- Demos
  - Flutter -> Dart Weather API backend 
  - Flutter -> Node Weather API backend
  - Dart backend service -> Dart backend service
  - Dart backend service -> non-Dart backend service

### Exporters
- Zipkin exporter 

## Flutter 

### Context Propagation
 - Flutter to Android
 - Flutter to iOS
 - Flutter to WebViews with js otel
 - Flutter to desktop platforms

# Navigation
 - Move Go_Router to a separate package
 - Support Navigtor internally
 - auto_route
 - Other routers?

### Hardening

- Saving unsent OTel data to disk