# Home Cluster Flux Entry Point

This directory contains the Flux desired state for the home cluster.

Bootstrap Flux with the GitHub repository path set to `clusters/home`, then let
the `flux-system` Kustomization reconcile the infrastructure Kustomizations in
`clusters/home/infrastructure.yaml`.

Helmsman remains the rollback path until the Flux resources have reconciled with
parity and the live releases have been checked.
