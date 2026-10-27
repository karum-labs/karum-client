# karum-client — Flutter UI (web is the judge target; same screens on desktop).
#
# The stack itself lives in karum-infra: `make local` there starts taste, AI,
# the gateway, and this client. The targets below delegate to it, so the same
# command works from this directory.
#
#   make local        start the whole stack (backends + Flutter)
#   make local-down   stop it
#   make run          run only this client against a running gateway
#   make test         run the widget and unit tests

INFRA := ../karum-infra
FLUTTER ?= flutter
DEVICE ?= chrome
GATEWAY_URL ?= http://127.0.0.1:8080

.PHONY: help local local-api local-down local-status pub-get run run-web build test analyze format clean

## help: list available targets.
help:
	@echo "local        start taste, AI, the gateway, and Flutter (delegates to karum-infra)"
	@echo "local-api    the same backends without the Flutter client"
	@echo "local-down   stop the processes make local started"
	@echo "local-status print the state of the local stack"
	@echo "pub-get      resolve packages for the Flutter SDK on this side"
	@echo "run          run this client on DEVICE against GATEWAY_URL"
	@echo "run-web      run this client on Chrome against GATEWAY_URL"
	@echo "build        build the web bundle in build/web"
	@echo "test         run the widget and unit tests"
	@echo "analyze      run the Dart analyzer"
	@echo "format       rewrite the sources with dart format"
	@echo "clean        remove the build directory"

## local: start taste, AI, the gateway, and Flutter on this machine.
local:
	$(MAKE) -C $(INFRA) local

## local-api: the same backends, without opening the Flutter client.
local-api:
	$(MAKE) -C $(INFRA) local-api

## local-down: stop the processes `make local` started.
local-down:
	$(MAKE) -C $(INFRA) local-down

## local-status: print the state of the local stack and its health endpoints.
local-status:
	$(MAKE) -C $(INFRA) local-status

## pub-get: resolve packages for the Flutter SDK on this side (Windows or WSL).
# `.dart_tool` is shared between the Windows and WSL checkouts, so switching
# hosts leaves a package_config.json with paths the other OS cannot read.
# Resolving first keeps `run`, `test`, and `analyze` from failing to find
# every Flutter type.
pub-get:
	$(FLUTTER) pub get

## run: run the app on DEVICE against GATEWAY_URL.
run: pub-get
	$(FLUTTER) run -d $(DEVICE) --dart-define=GATEWAY_URL=$(GATEWAY_URL)

## run-web: run the app on Chrome against GATEWAY_URL.
run-web: pub-get
	$(FLUTTER) run -d chrome --dart-define=GATEWAY_URL=$(GATEWAY_URL)

## build: build the web bundle in build/web.
build: pub-get
	$(FLUTTER) build web --dart-define=GATEWAY_URL=$(GATEWAY_URL)

## test: run the widget and unit tests.
test: pub-get
	$(FLUTTER) test

## analyze: run the Dart analyzer.
analyze: pub-get
	$(FLUTTER) analyze

## format: rewrite the sources with dart format.
format:
	$(FLUTTER) format lib test

## clean: remove the build directory.
clean:
	$(FLUTTER) clean
