SHELL := /bin/bash

ACTIONLINT ?= actionlint
HELM ?= helm
RENDER_DIR ?= /tmp/home-server-helm-rendered
YAMLLINT ?= yamllint

CHART_DIRS := $(shell find application -name Chart.yaml -exec dirname {} \; | sort)

.PHONY: help ci lint lint-actions lint-yaml helm-deps helm-lint helm-template helm-clean

help:
	@printf '%s\n' \
		'Available targets:' \
		'  ci             Run all local checks used by GitHub Actions.' \
		'  lint           Run workflow and YAML linting.' \
		'  lint-actions   Lint GitHub Actions workflows with actionlint.' \
		'  lint-yaml      Lint YAML values, manifests, and workflows with yamllint.' \
		'  helm-deps      Build dependencies for charts that declare them.' \
		'  helm-lint      Lint all Helm charts under application/.' \
		'  helm-template  Render all Helm charts under application/.' \
		'  helm-clean     Remove locally generated Helm dependency artifacts.'

ci: lint helm-lint helm-template

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
