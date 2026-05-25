# Staging Cluster Flux Entry Point

This is an ephemeral PR rehearsal root for the Kairos VM cluster. Bootstrap Flux
with the GitHub repository path set to `clusters/staging` and the branch set to
the PR branch being tested.

The scaffold is intentionally thin:

- infrastructure Kustomizations point at selected `clusters/home/infrastructure`
  paths needed to run the workloads;
- workload Kustomizations are thin Flux wrappers that point at
  `clusters/home/workloads/*` paths;
- staging runtime Secrets come from `private/flux/staging` and must use the same
  object names expected by the home manifests, with disposable values.

Do not add copied workload manifests here. `workloads.yaml` may list Flux
Kustomizations so the staging root can stay inside Kustomize's load boundary,
but each entry should point back at a `clusters/home/workloads/*` path. If a
workload needs a staging-only adjustment, prefer adding a staging-safe private
value or a small explicit patch with a comment explaining why the home
definition cannot be reused.

The root deliberately excludes home node-lifecycle and substrate pieces such as
Kured, system-upgrade plans, KubeVirt, and Kairos bootstrap. Those belong to the
cluster that hosts or installs the VM, not to the workload rehearsal running
inside it.
