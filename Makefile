SCHEME ?= Kuma
DESTINATION ?= platform=macOS
DERIVED_DATA ?= .build
CONFIGURATION ?= Debug

APP := $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/Kuma.app

XCODEBUILD := xcodebuild \
	-scheme $(SCHEME) \
	-destination '$(DESTINATION)' \
	-derivedDataPath $(DERIVED_DATA) \
	-configuration $(CONFIGURATION)

.PHONY: help build run open test clean

help:
	@echo "Kuma — common targets"
	@echo ""
	@echo "  make build   Build Kuma.app (output: $(APP))"
	@echo "  make run     Build and open the app"
	@echo "  make open    Open the app (must exist; run make build first)"
	@echo "  make test    Run KumaTests"
	@echo "  make clean   Remove $(DERIVED_DATA)"
	@echo ""
	@echo "Overrides: SCHEME, CONFIGURATION, DERIVED_DATA, DESTINATION"

build:
	$(XCODEBUILD) build

run: build
	open "$(APP)"

open:
	@test -d "$(APP)" || (echo "Missing $(APP) — run: make build" && exit 1)
	open "$(APP)"

test:
	$(XCODEBUILD) test

clean:
	rm -rf "$(DERIVED_DATA)"
