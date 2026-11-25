MOON_HOME ?= $(HOME)/.moon
export PATH := $(MOON_HOME)/bin:$(PATH)
export MOON_REGISTRY_API := 1

MOONBIT_RELEASE := 0.10.21+06da1ed44
MOON_VERSION := 0.1.20261117 (eb64713 2026-11-17)
MOON_BUILD := moon build --target js --release --deny-warn
RELEASE_JS := js/release/build/core/core.js
SHIPPED_JS := hooks/statusline.js

.PHONY: build check check-toolchain

build: check-toolchain
	$(MOON_BUILD)
	cp _build/$(RELEASE_JS) $(SHIPPED_JS)

check: check-toolchain
	moon fmt --check
	moon check --target js --deny-warn --no-mbti
	moon coverage clean
	moon test --target js --deny-warn --enable-coverage
	moon coverage report -f=full_summary > _build/coverage-summary.txt
	@awk '/^core\/.*\.mbt: [0-9]+\/[0-9]+$$/ && !/_(wb)?test\.mbt:/ { \
	    split($$NF, points, "/"); hit += points[1]; total += points[2] \
	  } END { \
	    if (!total) { print "MoonBit coverage report contains no production coverage points"; exit 1 } \
	    printf "MoonBit coverage points: %.2f%% (%d/%d; minimum 90%%)\n", 100 * hit / total, hit, total; \
	    if (10 * hit < 9 * total) exit 1 \
	  }' _build/coverage-summary.txt
	@set -eu; \
	  dir=$$(mktemp -d); \
	  trap 'rm -rf "$$dir"' 0; \
	  $(MOON_BUILD) --target-dir "$$dir"; \
	  cmp "$$dir/$(RELEASE_JS)" "$(SHIPPED_JS)" || { echo 'Run make build to regenerate $(SHIPPED_JS).' >&2; exit 1; }
	node --test scripts/git.integration.mjs
	npm run check:ts
	claude plugin validate --strict .
	claude plugin test .

check-toolchain:
	@if [ "$$(moon version)" != 'moon $(MOON_VERSION)' ] || \
	    [ "$$(moonc -v)" != 'v$(MOONBIT_RELEASE) (2026-11-16)' ] || \
	    [ "$$(moonrun --version)" != 'moonrun $(MOON_VERSION)' ]; then \
	  echo 'Install MoonBit $(MOONBIT_RELEASE) with the official installer.' >&2; exit 1; \
	fi
