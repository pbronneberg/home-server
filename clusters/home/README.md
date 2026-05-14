# Home Cluster Flux Entry Point

This directory contains the Flux desired state for the home cluster.

Bootstrap Flux with the GitHub repository path set to `clusters/home`, then let
the `flux-system` Kustomization reconcile the infrastructure Kustomizations in
`clusters/home/infrastructure.yaml` and workload Kustomizations in
`clusters/home/workloads.yaml`.

Infrastructure includes namespaces, Helm repositories, SOPS-backed private
secrets, cert-manager, Longhorn, kube-prometheus-stack monitoring, Traefik
middlewares, and retained storage classes. Workloads are reconciled separately
so application-facing releases can depend on the platform pieces they need.
