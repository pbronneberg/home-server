SHELL := /bin/bash

ACTIONLINT ?= actionlint
GITLEAKS ?= gitleaks
HELM ?= helm
RENDER_DIR ?= /tmp/home-server-helm-rendered
YAMLLINT ?= yamllint

CHART_DIRS := $(shell find application -name Chart.yaml -exec dirname {} \; | sort)

.PHONY: help ci lint lint-actions lint-yaml helm-deps helm-lint helm-template helm-clean scan-secrets scan-history check-public-redactions check-history-redactions public-check

help:
	@printf '%s\n' \
		'Available targets:' \
		'  ci             Run all local checks used by GitHub Actions.' \
		'  public-check   Run CI checks, secret scans, history scan, and redaction checks.' \
		'  lint           Run workflow and YAML linting.' \
		'  lint-actions   Lint GitHub Actions workflows with actionlint.' \
		'  lint-yaml      Lint YAML values, manifests, and workflows with yamllint.' \
		'  helm-deps      Build dependencies for charts that declare them.' \
		'  helm-lint      Lint all Helm charts under application/.' \
		'  helm-template  Render all Helm charts under application/.' \
		'  helm-clean     Remove locally generated Helm dependency artifacts.' \
		'  scan-secrets   Scan the current working tree for secrets with Gitleaks.' \
		'  scan-history   Scan all Git history for secrets with Gitleaks.' \
		'  check-public-redactions  Check tracked files for public unsafe topology.' \
		'  check-history-redactions Check Git history for public unsafe topology.'

ci: lint helm-lint helm-template

public-check: ci scan-secrets scan-history check-public-redactions check-history-redactions

lint: lint-actions lint-yaml

lint-actions:
	@if [ -d .github/workflows ]; then \
		$(ACTIONLINT); \
	else \
		printf '%s\n' 'No GitHub Actions workflows found.'; \
	fi

lint-yaml:
	$(YAMLLINT) .

helm-deps:
	@set -euo pipefail; \
	for chart in $(CHART_DIRS); do \
		if grep -Eq '^[[:space:]]*dependencies:' "$$chart/Chart.yaml"; then \
			printf 'Building Helm dependencies for %s\n' "$$chart"; \
			$(HELM) dependency build "$$chart"; \
		fi; \
	done

helm-lint: helm-deps
	@set -euo pipefail; \
	for chart in $(CHART_DIRS); do \
		printf 'Linting Helm chart %s\n' "$$chart"; \
		$(HELM) lint "$$chart"; \
	done

helm-template: helm-deps
	@set -euo pipefail; \
	rm -rf "$(RENDER_DIR)"; \
	mkdir -p "$(RENDER_DIR)"; \
	for chart in $(CHART_DIRS); do \
		release="$$(basename "$$chart")"; \
		output="$(RENDER_DIR)/$${release}.yaml"; \
		printf 'Rendering Helm chart %s to %s\n' "$$chart" "$$output"; \
		$(HELM) template "$$release" "$$chart" --namespace default > "$$output"; \
	done

helm-clean:
	@set -euo pipefail; \
	for chart in $(CHART_DIRS); do \
		rm -rf "$$chart/charts" "$$chart/Chart.lock"; \
	done; \
	rm -rf "$(RENDER_DIR)"

scan-secrets:
	@set -euo pipefail; \
	tmp_dir="$$(mktemp -d)"; \
	trap 'rm -rf "$$tmp_dir"' EXIT; \
	git ls-files -z --cached --others --exclude-standard | while IFS= read -r -d '' file; do \
		mkdir -p "$$tmp_dir/$$(dirname "$$file")"; \
		cp "$$file" "$$tmp_dir/$$file"; \
	done; \
	$(GITLEAKS) dir --no-banner --redact "$$tmp_dir"

scan-history:
	$(GITLEAKS) git --no-banner --redact --log-opts="--all" .

check-public-redactions:
	./scripts/check-public-redactions.sh

check-history-redactions:
	./scripts/check-history-redactions.sh
