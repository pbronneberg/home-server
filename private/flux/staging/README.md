# Staging Private Overlay

This overlay is applied inside the ephemeral PR staging cluster. It should hold
staging-safe runtime Secrets that use the same object names expected by the home
workload manifests, but with disposable credentials and staging hostnames.

Do not put home-side KubeVirt VM bootstrap values here; those are owned by the
home cluster private overlay.
