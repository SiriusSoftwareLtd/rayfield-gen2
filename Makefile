# Convenience targets for Rayfield Gen2.
# Requires GNU Make plus the Rokit-managed tools listed in rokit.toml.

.DEFAULT_GOAL := help

ROKIT ?= rokit
ROJO ?= rojo
LUNE ?= lune
STYLUA ?= stylua
SELENE ?= selene
LUAU_LSP ?= luau-lsp
TESTEZ ?= testez
CURL ?= curl
GIT ?= git
MKDIR ?= mkdir -p

SRC_DIR ?= src
TESTS_DIR ?= tests
SCRIPTS_DIR ?= scripts
PROJECT_FILE ?= default.project.json
TEST_PROJECT_FILE ?= test.project.json
WAX_PROJECT ?= wax.project.json
PLACE_FILE ?= Rayfield Gen2.rbxlx
TEST_PLACE_FILE ?= Rayfield Gen2 Tests.rbxlx
BUNDLE_FILE ?= build/bundled.luau
TESTEZ_MODEL ?= build/TestEZ.rbxm
TESTEZ_MODEL_URL ?= https://github.com/Roblox/testez/releases/download/v0.3.2/TestEZ.rbxm
SOURCEMAP ?= sourcemap.json
GLOBAL_TYPES ?= globalTypes.d.luau
GLOBAL_TYPES_URL ?= https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau

.PHONY: help install ci-format check test testez-model test-place format format-check lint typecheck build bundle serve sourcemap-watch dev clean

help:
	@echo Rayfield Gen2 Make targets:
	@echo   install    Trust and install Rokit tools
	@echo   check      Run the required format, lint, typecheck, and test gate
	@echo   test       Run unit tests for CI/local validation
	@echo   testez-model Download the TestEZ model used by Studio tests
	@echo   test-place Build the Roblox Studio test place
	@echo   format     Format Luau source with StyLua
	@echo   format-check Check Luau source formatting with StyLua
	@echo   lint       Lint Luau source with Selene
	@echo   typecheck  Generate sourcemap and run luau-lsp analysis
	@echo   build      Build the Rojo place file
	@echo   bundle     Build the release Luau bundle
	@echo   serve      Start the Rojo development server
	@echo   clean      Remove generated local outputs
	@echo   ci-format  Run the CI format, lint, typecheck
	@echo   dev        Start Rojo serve and watch sourcemap generation

install:
	$(ROKIT) trust rojo-rbx/rojo
	$(ROKIT) trust lune-org/lune
	$(ROKIT) trust seaofvoices/darklua
	$(ROKIT) trust JohnnyMorganz/StyLua
	$(ROKIT) trust Kampfkarren/selene
	$(ROKIT) trust JohnnyMorganz/luau-lsp
	$(ROKIT) trust Roblox/testez
	$(ROKIT) install

ci-format: format-check lint typecheck

check: format-check lint typecheck test
	@echo all checks passed

test:
	$(LUNE) run scripts/run-tests.luau

testez-model: $(TESTEZ_MODEL)

test-place: $(TESTEZ_MODEL)
	$(ROJO) build $(TEST_PROJECT_FILE) -o "$(TEST_PLACE_FILE)"

$(TESTEZ_MODEL):
	$(MKDIR) "$(dir $(TESTEZ_MODEL))"
	$(CURL) -fsSL -o "$(TESTEZ_MODEL)" "$(TESTEZ_MODEL_URL)"

format:
	$(STYLUA) --syntax Luau $(SRC_DIR) $(TESTS_DIR) $(SCRIPTS_DIR)

format-check:
	$(STYLUA) --syntax Luau --check $(SRC_DIR) $(TESTS_DIR) $(SCRIPTS_DIR)

lint:
	$(SELENE) generate-roblox-std
	$(SELENE) $(SRC_DIR)

typecheck:
	$(ROJO) sourcemap $(PROJECT_FILE) -o $(SOURCEMAP)
	$(CURL) -fsSL -o $(GLOBAL_TYPES) $(GLOBAL_TYPES_URL)
	$(LUAU_LSP) analyze --sourcemap=$(SOURCEMAP) --defs=$(GLOBAL_TYPES) --no-strict-dm-types $(SRC_DIR)

build:
	$(ROJO) build $(PROJECT_FILE) -o "$(PLACE_FILE)"

bundle:
	$(LUNE) run wax bundle output="$(BUNDLE_FILE)" input="$(WAX_PROJECT)" minify=true

serve:
	$(ROJO) serve $(PROJECT_FILE)

sourcemap-watch:
	$(ROJO) sourcemap $(PROJECT_FILE) -o $(SOURCEMAP) --watch

dev:
	$(MAKE) -j2 sourcemap-watch serve

clean:
	$(GIT) clean -fdX -- build $(SOURCEMAP) roblox.yml $(GLOBAL_TYPES) "$(PLACE_FILE)" "$(TEST_PLACE_FILE)"
