# Manual Worker Lifecycle

`milliard` and `marvin` are manual-start K3s workers. Pressing their physical
power button is the only way to add capacity. When a worker returns Ready after
a lifecycle-managed shutdown, `manual-worker-lifecycle` uncordons it and
restores Longhorn scheduling; workloads with the matching manual-worker
toleration can then schedule.

The lifecycle service never powers a node on and never reacts to an ordinary
cordon. This keeps System Upgrade Controller and other maintenance cordons
outside its authority.

Before enabling the Flux reconciliation, migrate the two existing workers to
the `manual-worker-lifecycle` SSH account and update their encrypted
`manual-worker-power` Secret. The account has a single sudo permission:
`/sbin/poweroff`. New Kairos media provisions this account automatically.

For the existing workers, run the bootstrap script while both are powered on:

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
drains while honoring PodDisruptionBudgets, and powers off only after replicas
and attachments are gone.

It blocks instead of powering off during an agent upgrade, for strict-local
storage, an evacuation timeout, an attachment that cannot detach, or a failed
drain. A blocked worker stays cordoned and powered on. After resolving the
condition, cancel and retry:

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
