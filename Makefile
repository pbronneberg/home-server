SHELL := /bin/bash

ACTIONLINT ?= actionlint
AGE_KEYGEN ?= age-keygen
GITLEAKS ?= gitleaks
HELM ?= helm
RENDER_DIR ?= /tmp/home-server-helm-rendered
SOPS ?= sops
SOPS_AGE_KEY_FILE ?= .sops/age/keys.txt
SOPS_FILE ?= private/home.sops.yaml
SOPS_DECRYPTED_FILE ?= private/home.decrypted.yaml
SOPS_FILES ?= private/*.sops.yaml
YAMLLINT ?= yamllint

CHART_DIRS := $(shell find application -name Chart.yaml -exec dirname {} \; | sort)
HELM_REPO_ROOT ?= /tmp/home-server-helm-repositories
HELM_REPO_CONFIG ?= $(HELM_REPO_ROOT)/repositories.yaml
HELM_REPO_CACHE ?= $(HELM_REPO_ROOT)/cache
HELM_REPOS := bitnami=https://charts.bitnami.com/bitnami
HELM_WITH_REPOS = HELM_REPOSITORY_CONFIG="$(HELM_REPO_CONFIG)" HELM_REPOSITORY_CACHE="$(HELM_REPO_CACHE)"
SOPS_WITH_AGE = SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)"

.PHONY: help ci lint lint-actions lint-yaml helm-repos helm-deps helm-lint helm-template helm-clean sops-check-key sops-keygen sops-decrypt sops-decrypt-file sops-edit sops-encrypt sops-updatekeys scan-secrets scan-history check-public-redactions check-history-redactions public-check

help:
	@printf '%s\n' \
		'Available targets:' \
		'  ci             Run all local checks used by GitHub Actions.' \
		'  public-check   Run CI checks, secret scans, history scan, and redaction checks.' \
		'  lint           Run workflow and YAML linting.' \
		'  lint-actions   Lint GitHub Actions workflows with actionlint.' \
		'  lint-yaml      Lint YAML values, manifests, and workflows with yamllint.' \
		'  helm-repos     Configure Helm repositories used by chart dependencies.' \
		'  helm-deps      Build dependencies for charts that declare them.' \
		'  helm-lint      Lint all Helm charts under application/.' \
		'  helm-template  Render all Helm charts under application/.' \
		'  helm-clean     Remove locally generated Helm dependency artifacts.' \
		'  sops-keygen        Create the local SOPS age key if missing.' \
		'  sops-decrypt       Print decrypted private values to stdout.' \
		'  sops-decrypt-file  Write decrypted private values to an ignored file.' \
		'  sops-edit          Edit encrypted private values with SOPS.' \
		'  sops-encrypt       Encrypt private values in place with SOPS.' \
		'  sops-updatekeys    Re-encrypt private overlays after age recipient changes.' \
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

helm-repos:
	@set -euo pipefail; \
	mkdir -p "$(HELM_REPO_ROOT)" "$(HELM_REPO_CACHE)"; \
	for repo in $(HELM_REPOS); do \
		name="$${repo%%=*}"; \
		url="$${repo#*=}"; \
		printf 'Configuring Helm repository %s (%s)\n' "$$name" "$$url"; \
		$(HELM_WITH_REPOS) $(HELM) repo add "$$name" "$$url" --force-update >/dev/null; \
	done; \
	$(HELM_WITH_REPOS) $(HELM) repo update

helm-deps: helm-repos
	@set -euo pipefail; \
	for chart in $(CHART_DIRS); do \
		if grep -Eq '^[[:space:]]*dependencies:' "$$chart/Chart.yaml"; then \
			printf 'Building Helm dependencies for %s\n' "$$chart"; \
			$(HELM_WITH_REPOS) $(HELM) dependency build "$$chart" --skip-refresh; \
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
	rm -rf "$(RENDER_DIR)" "$(HELM_REPO_ROOT)"

sops-check-key:
	@test -f "$(SOPS_AGE_KEY_FILE)" || { \
		printf 'Missing SOPS age key: %s\n' "$(SOPS_AGE_KEY_FILE)" >&2; \
		printf 'Create or restore it before decrypting private overlays.\n' >&2; \
		exit 1; \
	}

sops-keygen:
	@set -euo pipefail; \
	key_file="$(SOPS_AGE_KEY_FILE)"; \
	if [ -e "$$key_file" ]; then \
		printf 'SOPS age key already exists: %s\n' "$$key_file" >&2; \
		exit 1; \
	fi; \
	mkdir -p "$$(dirname "$$key_file")"; \
	$(AGE_KEYGEN) -o "$$key_file"

sops-decrypt: sops-check-key
	$(SOPS_WITH_AGE) $(SOPS) decrypt "$(SOPS_FILE)"

sops-decrypt-file: sops-check-key
	@set -euo pipefail; \
	umask 077; \
	printf 'Writing decrypted private values to %s\n' "$(SOPS_DECRYPTED_FILE)"; \
	$(SOPS_WITH_AGE) $(SOPS) decrypt "$(SOPS_FILE)" > "$(SOPS_DECRYPTED_FILE)"

sops-edit: sops-check-key
	$(SOPS_WITH_AGE) $(SOPS) "$(SOPS_FILE)"

sops-encrypt: sops-check-key
	$(SOPS_WITH_AGE) $(SOPS) --encrypt --in-place "$(SOPS_FILE)"

sops-updatekeys: sops-check-key
	$(SOPS_WITH_AGE) $(SOPS) updatekeys --yes $(SOPS_FILES)

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
