.PHONY: protos clean-protos

protos:
	chmod +x tool/setup_protos.sh
	./tool/setup_protos.sh

clean-protos:
	rm -rf lib/src/gen
	rm -rf protos/opentelemetry-proto

generate: protos