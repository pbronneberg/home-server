FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ARG ACTIONLINT_VERSION=1.7.12
ARG CODEX_VERSION=0.130.0
ARG GITLEAKS_VERSION=8.30.1
ARG GIT_FILTER_REPO_VERSION=2.47.0
ARG HELM_VERSION=3.19.0
ARG SOPS_VERSION=3.11.0
ARG TARGETARCH
ARG YAMLLINT_VERSION=1.38.0

ENV PATH="/opt/home-server-tools/bin:${PATH}"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      age \
      ca-certificates \
      curl \
      git \
      gzip \
      jq \
      less \
      make \
      nodejs \
      npm \
      openssh-client \
      python3 \
      python3-venv \
      ripgrep \
      tar \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g "@openai/codex@${CODEX_VERSION}"

RUN python3 -m venv /opt/home-server-tools \
    && /opt/home-server-tools/bin/python -m pip install --no-cache-dir --upgrade pip \
    && /opt/home-server-tools/bin/python -m pip install --no-cache-dir \
      "git-filter-repo==${GIT_FILTER_REPO_VERSION}" \
      "yamllint==${YAMLLINT_VERSION}"

RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) helm_arch="amd64"; actionlint_arch="amd64"; gitleaks_arch="x64"; sops_arch="amd64" ;; \
      arm64) helm_arch="arm64"; actionlint_arch="arm64"; gitleaks_arch="arm64"; sops_arch="arm64" ;; \
      *) echo "Unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${helm_arch}.tar.gz" \
      | tar -xz -C /tmp; \
    mv "/tmp/linux-${helm_arch}/helm" /usr/local/bin/helm; \
    rm -rf "/tmp/linux-${helm_arch}"; \
    curl -fsSL "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/actionlint_${ACTIONLINT_VERSION}_linux_${actionlint_arch}.tar.gz" \
      | tar -xz -C /tmp actionlint; \
    mv /tmp/actionlint /usr/local/bin/actionlint; \
    curl -fsSL "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_${gitleaks_arch}.tar.gz" \
      | tar -xz -C /tmp gitleaks; \
    mv /tmp/gitleaks /usr/local/bin/gitleaks; \
    curl -fsSL -o /usr/local/bin/sops "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.${sops_arch}"; \
    chmod +x /usr/local/bin/helm /usr/local/bin/actionlint /usr/local/bin/gitleaks /usr/local/bin/sops

RUN actionlint --version \
    && codex --version \
    && gitleaks version \
    && helm version --short \
    && sops --version \
    && yamllint --version \
    && git-filter-repo --version
