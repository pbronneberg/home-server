# Security Hardening Runbook

This runbook keeps security improvements audit-first and GitOps-friendly. It is
documentation-only except for the repo checks it references.

## Rollout Order

1. Run the report-only audit:

```bash
make security-audit
```

2. Fix rendered-manifest findings before enabling live enforcement.

   Pod Security starts with `audit` and `warn` namespace labels. Do not add
   `enforce=restricted` to an application namespace until its workloads render
   cleanly and the live pods have been checked after a Flux reconcile.

3. Protect sensitive ingresses first.

   Public websites can keep only the HTTPS redirect middleware. Home Assistant,
   Longhorn admin, monitoring endpoints, S3 admin/API exposure, and home-control
   proxy hosts should include `default-github-oauth@kubernetescrd`; keep
   `default-basic-auth@kubernetescrd` only as a secondary fallback where it is
   already expected.

4. Enable NetworkPolicy per workload after traffic is known.

   The first-party charts include disabled NetworkPolicy templates. Turn them
   on one workload at a time from private values or a small reviewed PR, then
   verify ingress, DNS, monitoring, and required backend traffic before moving
   to the next workload.

5. Treat legacy image and data-volume exceptions as migration work.

   Some current images still bind privileged ports or existing PVC data with
   root-owned files. Keep lower-risk controls like token automount disabling and
   seccomp where compatible, then move those workloads to non-root images or
   corrected volume ownership in a separate rollout.

## Host And Cluster Checks

- Install K3s with a private kubeconfig mode, for example
  `--write-kubeconfig-mode 600`.
- Keep GitHub-hosted CI free of kubeconfigs, cluster tokens, and deployment
  credentials.
- Verify K3s secret encryption before storing long-lived credentials in the
  cluster.
- Review host SSH and firewall exposure outside Kubernetes; the repository
  should not contain real firewall rules, LAN CIDRs, or host allowlists in
  plaintext.
- Keep Flux deploy credentials read-only for steady-state pulls. Use short-lived
  elevated credentials only for bootstrap.

## Storage And Recovery

- The current storage layout is not migrated by this hardening pass.
- Treat `local-path` PVCs as node-local data until deliberately moved or backed
  up.
- Multiple default StorageClasses should be resolved in a storage-focused PR so
  new PVC placement is predictable.
- Watch image filesystem pressure during upgrades and after large image churn.
- Keep Longhorn backup target health and restore drills on the recovery backlog;
  do not rely on snapshots as the only copy of important data.
- MongoDB auth for existing Photobooth data remains opt-in until the application
  connection string and existing database users are migrated together.

## Drift Cleanup Queue

- Decide whether the legacy runner manifests and empty runner namespaces should
  be removed or adopted.
- Remove stale Secrets and old workload resources only after confirming they are
  not referenced by Helm history, cert-manager, or recovery workflows.
- Replace the TLS proxy chart's legacy `Endpoints` object with `EndpointSlice`
  in a separate PR so ingress behavior is easy to review.
