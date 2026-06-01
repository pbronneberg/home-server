FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# renovate: datasource=github-releases depName=rhysd/actionlint extractVersion=^v(?<version>.*)$
ARG ACTIONLINT_VERSION=1.7.12
# renovate: datasource=npm depName=@openai/codex
ARG CODEX_VERSION=0.135.0
# renovate: datasource=github-releases depName=sigstore/cosign extractVersion=^v(?<version>.*)$
ARG COSIGN_VERSION=3.0.6
# renovate: datasource=github-releases depName=fluxcd/flux2 extractVersion=^v(?<version>.*)$
ARG FLUX_VERSION=2.8.8
# renovate: datasource=github-releases depName=gitleaks/gitleaks extractVersion=^v(?<version>.*)$
ARG GITLEAKS_VERSION=8.30.1
# renovate: datasource=github-releases depName=cli/cli extractVersion=^v(?<version>.*)$
ARG GH_VERSION=2.93.0
# renovate: datasource=pypi depName=git-filter-repo
ARG GIT_FILTER_REPO_VERSION=2.47.0
# renovate: datasource=github-releases depName=helm/helm extractVersion=^v(?<version>.*)$
ARG HELM_VERSION=4.2.0
# renovate: datasource=github-releases depName=kubernetes/kubernetes extractVersion=^v(?<version>.*)$
ARG KUBECTL_VERSION=1.36.1
# renovate: datasource=github-releases depName=kubevirt/kubevirt extractVersion=^v(?<version>.*)$
ARG KUBEVIRT_VERSION=1.8.2
# renovate: datasource=github-releases depName=int128/kubelogin extractVersion=^v(?<version>.*)$
ARG KUBELOGIN_VERSION=1.36.1
# renovate: datasource=github-releases depName=kubernetes-sigs/kustomize extractVersion=^kustomize/v(?<version>.*)$
ARG KUSTOMIZE_VERSION=5.8.1
# renovate: datasource=github-releases depName=getsops/sops extractVersion=^v(?<version>.*)$
ARG SOPS_VERSION=3.13.1
ARG TARGETARCH
# renovate: datasource=pypi depName=yamllint
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
      unzip \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g "@openai/codex@${CODEX_VERSION}"

RUN python3 -m venv /opt/home-server-tools \
    && /opt/home-server-tools/bin/python -m pip install --no-cache-dir --upgrade pip \
    && /opt/home-server-tools/bin/python -m pip install --no-cache-dir \
      "git-filter-repo==${GIT_FILTER_REPO_VERSION}" \
      "yamllint==${YAMLLINT_VERSION}"

RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) helm_arch="amd64"; actionlint_arch="amd64"; gitleaks_arch="x64"; gh_arch="amd64"; sops_arch="amd64"; flux_arch="amd64"; kustomize_arch="amd64"; kubelogin_arch="amd64"; cosign_arch="amd64" ;; \
      arm64) helm_arch="arm64"; actionlint_arch="arm64"; gitleaks_arch="arm64"; gh_arch="arm64"; sops_arch="arm64"; flux_arch="arm64"; kustomize_arch="arm64"; kubelogin_arch="arm64"; cosign_arch="arm64" ;; \
      *) echo "Unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/fluxcd/flux2/releases/download/v${FLUX_VERSION}/flux_${FLUX_VERSION}_linux_${flux_arch}.tar.gz" \
      | tar -xz -C /tmp flux; \
    mv /tmp/flux /usr/local/bin/flux; \
    curl -fsSL -o /usr/local/bin/cosign "https://github.com/sigstore/cosign/releases/download/v${COSIGN_VERSION}/cosign-linux-${cosign_arch}"; \
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
    curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${gh_arch}.tar.gz" \
      | tar -xz -C /tmp "gh_${GH_VERSION}_linux_${gh_arch}/bin/gh"; \
    mv "/tmp/gh_${GH_VERSION}_linux_${gh_arch}/bin/gh" /usr/local/bin/gh; \
    rm -rf "/tmp/gh_${GH_VERSION}_linux_${gh_arch}"; \
    curl -fsSL -o /usr/local/bin/kubectl "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl"; \
    curl -fsSL -o /usr/local/bin/virtctl "https://github.com/kubevirt/kubevirt/releases/download/v${KUBEVIRT_VERSION}/virtctl-v${KUBEVIRT_VERSION}-linux-${TARGETARCH}"; \
    ln -s /usr/local/bin/virtctl /usr/local/bin/kubectl-virt; \
    curl -fsSL "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_${kustomize_arch}.tar.gz" \
      | tar -xz -C /tmp kustomize; \
    mv /tmp/kustomize /usr/local/bin/kustomize; \
    curl -fsSL -o /tmp/kubelogin.zip "https://github.com/int128/kubelogin/releases/download/v${KUBELOGIN_VERSION}/kubelogin_linux_${kubelogin_arch}.zip"; \
    unzip -q /tmp/kubelogin.zip -d /tmp/kubelogin; \
    mv /tmp/kubelogin/kubelogin /usr/local/bin/kubectl-oidc_login; \
    ln -s /usr/local/bin/kubectl-oidc_login /usr/local/bin/kubelogin; \
    rm -rf /tmp/kubelogin /tmp/kubelogin.zip; \
    curl -fsSL -o /usr/local/bin/sops "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.${sops_arch}"; \
    chmod +x /usr/local/bin/flux /usr/local/bin/cosign /usr/local/bin/helm /usr/local/bin/actionlint /usr/local/bin/gitleaks /usr/local/bin/gh /usr/local/bin/kubectl /usr/local/bin/virtctl /usr/local/bin/kubectl-virt /usr/local/bin/kubectl-oidc_login /usr/local/bin/kustomize /usr/local/bin/sops

RUN actionlint --version \
    && codex --version \
    && cosign version --json \
    && flux --version \
    && gitleaks version \
    && gh --version \
    && helm version --short \
    && kubectl version --client \
    && virtctl version --client \
    && kubectl virt version --client \
    && kubectl oidc-login version \
    && kustomize version \
    && sops --version \
    && yamllint --version \
    && git-filter-repo --version
