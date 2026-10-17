SHELL := bash
.SHELLFLAGS := -euo pipefail -c
.DELETE_ON_ERROR:

ELM := elm
ELM_FORMAT := ./node_modules/.bin/elm-format
ELM_TEST := ./node_modules/.bin/elm-test
ELM_REVIEW := ./node_modules/.bin/elm-review
TERSER := ./node_modules/.bin/terser

TERSER_FUNCS := pure_funcs=[F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9]
TERSER_OPTS := pure_getters,keep_fargs=false,unsafe_comps,unsafe
TERSER_FLAGS := $(TERSER_FUNCS),$(TERSER_OPTS)

PORT ?= 8080

.DEFAULT_GOAL := default

.PHONY: default help deps format check lint test build run parity ci clean
.PHONY: distclean

help: ## Show this help message
	@echo "Available targets:"
	@awk 'match($$0, /^([a-zA-Z_-]+):.*##[[:space:]]*(.*)$$/, m) { \
		printf "  \033[1;36m%-16s\033[0m %s\n", m[1], m[2] \
	}' $(MAKEFILE_LIST) | sort

default: format check lint test build  ## Run all default verification targets

deps: ## Install npm development dependencies
	@echo "Installing npm dependencies..."
	@npm ci

format: ## Format Elm sources and test files
	@echo "Formatting Elm files..."
	@$(ELM_FORMAT) --yes src tests review

check: ## Type-check Elm sources and validate formatting
	@echo "Checking formatting..."
	@$(ELM_FORMAT) --validate src tests review
	@echo "Type-checking Elm sources..."
	@$(ELM) make src/Main.elm --output=/dev/null

lint: ## Validate formatting and execute elm-review
	@echo "Checking formatting..."
	@$(ELM_FORMAT) --validate src tests review
	@echo "Running elm-review..."
	@$(ELM_REVIEW)

test: ## Execute Elm unit and property tests
	@echo "Running tests..."
	@$(ELM_TEST)

build: ## Build optimised production assets in dist/
	@echo "Building production bundle..."
	@rm -rf dist
	@mkdir -p dist
	@cp -r static/* dist/
	@$(ELM) make src/Main.elm --optimize --output=dist/elm.js
	@$(TERSER) dist/elm.js --compress '$(TERSER_FLAGS)' \
		| $(TERSER) --mangle --output dist/elm.min.js
	@rm dist/elm.js
	@echo "Build complete in dist/"

run: build ## Run local HTTP server on port $(PORT)
	@echo "Serving dist/ on http://localhost:$(PORT)..."
	@python3 -m http.server $(PORT) --directory dist

parity: ## Run parity comparison against Haskell reconstruct-strings binary
	@echo "Running parity tests against Haskell reconstruct-strings..."
	@./scripts/parity.sh

ci: lint test build parity ## Run full CI pipeline validation

clean: ## Clean build artefacts and compiler caches
	@echo "Cleaning artefacts..."
	@rm -rf elm-stuff dist build review/elm-stuff

distclean: clean ## Remove all build artefacts and node_modules
	@echo "Cleaning dependencies..."
	@rm -rf node_modules
