# Kairos Hardware Install Media

This directory is the Git-backed source for physical Kairos agent install
media. It keeps the reusable cloud-config scaffold and non-secret node values
reviewable while the rendered media stays ignored under `.local/kairos`.

- `user-data.agent.yaml` is the shared scaffold for physical agent nodes.
- `nodes.yaml` holds per-node non-secret hardware values such as hostnames,
  install disks, the K3s API endpoint, and optional data-disk preparation.
- `private/flux/home/kairos-bootstrap-values.sops.yaml` holds the K3s join
  token used by the renderer.

Render one node:

```bash
make kairos-render-node KAIROS_NODE=milliard
```

Render the currently defined hardware nodes:

```bash
make kairos-render-hardware
```

The renderer writes:

- `.local/kairos/<node>/user-data`
- `.local/kairos/<node>/cidata/user-data`
- `.local/kairos/<node>/cidata/meta-data`
- `.local/kairos/<node>/<node>-cidata.iso`

Do not commit rendered `.local` files. They contain the decrypted K3s join
token.
