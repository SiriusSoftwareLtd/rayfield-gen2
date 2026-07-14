# Convenience targets for Rayfield Gen2.
# Requires GNU Make plus the Rokit-managed tools listed in rokit.toml.

.DEFAULT_GOAL := help

ROKIT ?= rokit
ROJO ?= rojo
LUNE ?= lune
STYLUA ?= stylua
SELENE ?= selene
LUAU_LSP ?= luau-lsp
CURL ?= curl
GIT ?= git

SRC_DIR ?= src
PROJECT_FILE ?= default.project.json
WAX_PROJECT ?= wax.project.json
PLACE_FILE ?= Rayfield Gen2.rbxlx
BUNDLE_FILE ?= build/bundled.luau
SOURCEMAP ?= sourcemap.json
GLOBAL_TYPES ?= globalTypes.d.luau
GLOBAL_TYPES_URL ?= https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau

.PHONY: help install ci check format format-check lint typecheck build bundle serve sourcemap-watch dev clean

help:
	@echo Rayfield Gen2 Make targets:
	@echo   install    Trust and install Rokit tools
	@echo   check      Run the required format, lint, and typecheck gate
	@echo   format     Format Luau source with StyLua
	@echo   format-check Check Luau source formatting with StyLua
	@echo   lint       Lint Luau source with Selene
	@echo   typecheck  Generate sourcemap and run luau-lsp analysis
	@echo   build      Build the Rojo place file
	@echo   bundle     Build the release Luau bundle
	@echo   serve      Start the Rojo development server
	@echo   clean      Remove generated local outputs
	@echo   ci         Run the CI format, lint, and typecheck gate
	@echo   dev        Start Rojo serve and watch sourcemap generation

install:
	$(ROKIT) trust rojo-rbx/rojo
	$(ROKIT) trust lune-org/lune
	$(ROKIT) trust seaofvoices/darklua
	$(ROKIT) trust JohnnyMorganz/StyLua
	$(ROKIT) trust Kampfkarren/selene
	$(ROKIT) trust JohnnyMorganz/luau-lsp
	$(ROKIT) install

ci: check

check: format-check lint typecheck
	@echo all checks passed

format:
	$(STYLUA) --syntax Luau $(SRC_DIR)

format-check:
	$(STYLUA) --syntax Luau --check $(SRC_DIR)

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
	$(GIT) clean -fdX -- build $(SOURCEMAP) roblox.yml $(GLOBAL_TYPES) "$(PLACE_FILE)"
