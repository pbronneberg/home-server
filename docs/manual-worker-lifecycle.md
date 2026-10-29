# Manual Worker Lifecycle

`milliard` and `marvin` are manual-start K3s workers. Pressing their physical
power button is the only way to add capacity. When a worker returns Ready after
a lifecycle-managed shutdown, `manual-worker-lifecycle` uncordons it and
restores Longhorn scheduling; workloads with the matching manual-worker
toleration can then schedule.

The lifecycle service never powers a node on and never reacts to an ordinary
cordon. This keeps System Upgrade Controller and other maintenance cordons
outside its authority.

## Existing worker migration

Complete this migration before resuming the root `flux-system` Kustomization
with the replacement controller change. That prevents Flux pruning the old
controller before both existing workers are ready. Keep both workers powered
on and preserve their Node and PVC identities throughout.

1. Confirm both workers are Ready and check for active upgrades, Longhorn
   rebuilds, and attached volumes. Do not begin during maintenance or storage
   recovery.
2. Suspend root reconciliation and the old worker lifecycle controller while
   applying this change:

   ```bash
   flux suspend kustomization flux-system -n flux-system
   flux suspend kustomization infrastructure-homelab-autoscaler -n flux-system
   flux suspend helmrelease homelab-autoscaler -n homelab-autoscaler-system
   kubectl scale deployment homelab-autoscaler-controller-manager \
     -n homelab-autoscaler-system --replicas=0
   ```

   Verify the old controller Deployment has zero replicas before changing live
   node labels or taints. Workers remain powered on while autoscaler
   reconciliation is paused.

3. While both nodes are online, bootstrap the restricted poweroff account:

   ```bash
   ./scripts/bootstrap-autoscaler-shutdown-user.sh milliard marvin
   ```

   Reconcile the encrypted `manual-worker-power` Secret with each worker's
   current SSH host key and the account key. The account has a single sudo
   permission: `/sbin/poweroff`. New Kairos media provisions this account
   automatically.
4. On each worker, merge the new labels and taint into the persistent K3s agent
   configuration (`/etc/rancher/k3s/config.yaml`), preserving unrelated
   settings. The desired entries are:

   ```yaml
   node-label:
     - home-server.dev/node-role=manual-worker
     - home-server.dev/storage=local
     - home-server.dev/power-policy=manual-start
     - node.longhorn.io/create-default-disk=false
   node-taint:
     - home-server.dev/manual-worker=true:NoSchedule
   ```

   Replace the old `home-server.dev/node-role=autoscaled-worker`,
   `home-server.dev/autoscaled=true`, and `home-server.dev/power-mode=manual-wake`
   labels. Remove the `home-server.dev/autoscaled=true:NoSchedule` taint and,
   on `marvin`, the `home-server.dev/manual-wake=true:NoSchedule` taint. Remove
   those same old labels and taints from the live Node, then apply the desired
   entries. Restart `k3s-agent` one worker at a time only if required for its
   persistent configuration to take effect; wait for Ready and healthy
   Longhorn replicas before proceeding to the other worker.
5. Verify both live Nodes have `power-policy=manual-start`, the expected role
   and storage labels, the manual-worker taint, and no retired autoscaler or
   manual-wake labels/taints. Verify their K3s agent configuration matches,
   their Ready condition is True, Longhorn scheduling is enabled, and the
   restricted SSH key succeeds in batch mode. Confirm the encrypted Secret is
   reconciled before allowing Flux to switch controllers.
6. Merge/resume the Flux change, then verify the new Kustomization is Ready,
   its CronJob and ConfigMap are in `manual-worker-lifecycle-system`, and the
   old autoscaler Kustomization and resources are pruned. Do not test shutdown
   until those checks pass.

If the replacement fails, suspend root reconciliation again and keep workers
powered on. Restore the previous persistent K3s labels/taints on each node:
`node-role=autoscaled-worker`, `autoscaled=true`, and `power-mode=manual-wake`
on `marvin`; restore the old `autoscaled=true:NoSchedule` taint on both and
`manual-wake=true:NoSchedule` on `marvin`. Restore/remove the corresponding
live labels and taints, verify both Nodes Ready and Longhorn healthy, and
restore the old encrypted power Secret and source configuration. Revert the
desired-state change so the old autoscaler Kustomization and its source return;
resume root reconciliation only after that desired state is reviewed. Verify
the old Kustomization and HelmRelease are Ready and the old controller is
healthy before considering rollback complete. Do not delete or recreate Nodes,
Longhorn resources, or PVCs.

The migration and rollback steps above are operator procedures; no live
cluster changes have been made by this branch work.

```bash
./scripts/bootstrap-autoscaler-shutdown-user.sh milliard marvin
```

## Shutdown

```bash
make worker-shutdown NODE=milliard
make worker-shutdown-status NODE=milliard
```

The command cordons a manual worker and writes an explicit request. The
reconciler disables Longhorn scheduling, requests native replica eviction,
waits for replica evacuation, drains while honoring PodDisruptionBudgets, then
waits up to ten minutes for attachments to detach before requesting poweroff.
Cancellation is acknowledged by the reconciler before it restores scheduling.
During the first two minutes of `poweroff-starting`, cancellation is refused
while the bounded SSH request may still be running. If that phase remains after
two minutes, the cancel command can clear the stale request through the same
reconciler restoration path.

It blocks instead of powering off when safety state cannot be read, during an
agent upgrade, for strict-local storage, an evacuation/detachment timeout, or a
failed drain. A blocked worker stays cordoned and powered on. After resolving
the condition, cancel and retry:

```bash
make worker-cancel-shutdown NODE=milliard
make worker-shutdown NODE=milliard
```

## K3s maintenance

Agent upgrades are opt-in. Power on the worker, wait for Ready, then run:

```bash
make worker-upgrade NODE=milliard
make worker-upgrade-status NODE=milliard
```

Remove `home-server.dev/k3s-upgrade=enabled` after the agent Plan completes.
The lifecycle service refuses shutdown while a System Upgrade Controller Pod is
active on the worker.
