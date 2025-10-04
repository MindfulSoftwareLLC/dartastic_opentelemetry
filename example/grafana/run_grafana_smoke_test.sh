
# Language guides: https://grafana.com/docs/grafana-cloud/monitor-applications/application-observability/setup/quickstart/
export OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"
export OTEL_EXPORTER_OTLP_ENDPOINT="https://otlp-gateway-prod-<YOUR_GATEWAY>.grafana.net/otlp"
# Python requires "Basic%20" instead of "Basic "
export OTEL_EXPORTER_OTLP_HEADERS="Authorization=Basic <YOUR_KEY>"
export OTEL_LOG_LEVEL="DEBUG"

dart ./grafana_smoke_test.dart
