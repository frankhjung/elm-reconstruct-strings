.DEFAULT_GOAL := help
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables

SHELL := bash
.SHELLFLAGS := -euo pipefail -c

ELM := $(shell if [ -x ./node_modules/.bin/elm ]; then \
	echo ./node_modules/.bin/elm; \
elif which elm >/dev/null 2>&1; then \
	which elm; \
else \
	echo npx elm; \
fi)

ELM_FORMAT := $(shell if [ -x ./node_modules/.bin/elm-format ]; then \
	echo ./node_modules/.bin/elm-format; \
elif which elm-format >/dev/null 2>&1; then \
	which elm-format; \
else \
	echo npx elm-format; \
fi)

ELM_TEST := $(shell if [ -x ./node_modules/.bin/elm-test ]; then \
	echo ./node_modules/.bin/elm-test; \
elif which elm-test >/dev/null 2>&1; then \
	which elm-test; \
else \
	echo npx elm-test; \
fi)

ELM_REVIEW := $(shell if [ -x ./node_modules/.bin/elm-review ]; then \
	echo ./node_modules/.bin/elm-review; \
elif which elm-review >/dev/null 2>&1; then \
	which elm-review; \
else \
	echo npx elm-review; \
fi)

TERSER := $(shell if [ -x ./node_modules/.bin/terser ]; then \
	echo ./node_modules/.bin/terser; \
elif which terser >/dev/null 2>&1; then \
	which terser; \
else \
	echo npx terser; \
fi)

ELM_MAIN := src/Main.elm
DIST_DIR := dist
HASKELL_DIR := $(HOME)/dev/haskell/reconstruct-strings

.PHONY: help default deps format check lint test
.PHONY: build run parity ci clean distclean

default: help

help: ## Display available targets
	@awk 'BEGIN {FS = ":.*?## "}; \
		/^[a-zA-Z_-]+:.*?## / \
		{printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}' \
		$(MAKEFILE_LIST)

deps: ## Install development dependencies
	@if [ ! -d node_modules ]; then npm install; fi

format: ## Format all Elm source, test, and review files
	$(ELM_FORMAT) src/ tests/ review/ --yes

check: ## Type-check Elm sources and validate formatting
	$(ELM_FORMAT) src/ tests/ review/ --validate
	$(ELM) make $(ELM_MAIN) --output=/dev/null

lint: ## Run elm-review static analysis rules
	$(ELM_REVIEW)

test: ## Execute unit and fuzz property tests
	$(ELM_TEST)

build: check ## Compile and minify production bundle in dist/
	mkdir -p $(DIST_DIR)
	$(ELM) make $(ELM_MAIN) --optimize --output=$(DIST_DIR)/elm.js
	$(TERSER) $(DIST_DIR)/elm.js \
		--compress "pure_funcs=[F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9]" \
		--compress "pure_getters,keep_fargs=false,unsafe_comps,unsafe" \
		--mangle \
		--output $(DIST_DIR)/elm.min.js
	rm -f $(DIST_DIR)/elm.js
	cp -r static/* $(DIST_DIR)/

run: build ## Serve production bundle locally at http://localhost:8080
	python3 -m http.server 8080 -d $(DIST_DIR)

parity: ## Execute differential parity tests against Haskell reference binary
	@if [ -d "$(HASKELL_DIR)" ]; then \
		echo "Running differential parity tests against $(HASKELL_DIR)..."; \
		bash scripts/parity.sh; \
	else \
		echo "Skipping parity: $(HASKELL_DIR) not found."; \
	fi

ci: check lint test build parity ## Run continuous integration suite

clean: ## Remove production build artefacts
	rm -rf $(DIST_DIR)

distclean: clean ## Remove all build artefacts, caches, and node_modules
	rm -rf elm-stuff review/elm-stuff node_modules
