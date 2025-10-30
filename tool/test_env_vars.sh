# Test a single env var with both POSIX and --define
test_env_var() {
  local var_name="$1"
  local test_value="$2"

  echo -e "${BLUE}Testing: $var_name${NC}"

  # Test 1: POSIX environment variable (always use commas)
  OUTPUT=$(env "$var_name=$test_value" dart "$READ_ALL_PROG" text 2>&1)
  verify_env_value "$var_name" "$test_value" "$OUTPUT" "POSIX"

  # Test 2: --define (use semicolons for comma-separated values)
  local define_value="$test_value"
  case "$var_name" in
    OTEL_RESOURCE_ATTRIBUTES|OTEL_PROPAGATORS|OTEL_EXPORTER_OTLP_HEADERS|OTEL_EXPORTER_OTLP_TRACES_HEADERS|OTEL_EXPORTER_OTLP_METRICS_HEADERS|OTEL_EXPORTER_OTLP_LOGS_HEADERS)
      # Replace commas with semicolons for --define compatibility
      define_value="${test_value//,/;}"
      ;;
  esac

  local temp_exe="$PROJECT_DIR/.tmp_test_compiled"
  if COMPILE_OUTPUT=$(dart compile exe "--define=${var_name}=${define_value}" "$READ_ALL_PROG" -o "$temp_exe" 2>&1); then
    OUTPUT=$("$temp_exe" text 2>&1)
    verify_env_value "$var_name" "$test_value" "$OUTPUT" "--define"
    rm -f "$temp_exe"
  else
    echo -e "${RED}  ✗ [--define] compilation failed for $var_name${NC}"
    echo -e "${RED}     Command: dart compile exe \"--define=${var_name}=${define_value}\" \"$READ_ALL_PROG\" -o \"$temp_exe\"${NC}"
    echo -e "${RED}     Error: $COMPILE_OUTPUT${NC}"
    FAILED_TESTS+=("[--define] $var_name - compilation failed")
    ((FAILED++))
  fi

  return 0
}