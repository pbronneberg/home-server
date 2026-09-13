from __future__ import annotations

import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[2] / "scripts" / "check-flux-cluster-domain.sh"


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(textwrap.dedent(content).lstrip(), encoding="utf-8")


class CheckFluxClusterDomainTests(unittest.TestCase):
    def test_accepts_non_default_home_cluster_domain(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write(
                root / "clusters/home/infrastructure.yaml",
                """
                apiVersion: kustomize.toolkit.fluxcd.io/v1
                kind: Kustomization
                spec:
                  postBuild:
                    substitute:
                      KAIROS_CLUSTER_DOMAIN: home-server.bronneberg.local
                """,
            )
            write(
                root / "clusters/home/flux-system/gotk-components.yaml",
                """
                args:
                  - --events-addr=http://notification-controller.$(RUNTIME_NAMESPACE).svc.home-server.bronneberg.local./
                """,
            )
            result = subprocess.run(
                ["bash", str(SCRIPT)],
                cwd=root,
                check=False,
                text=True,
                capture_output=True,
            )
            self.assertEqual(0, result.returncode, result.stderr)
            self.assertIn("do not use svc.cluster.local", result.stdout)

    def test_allows_missing_inline_cluster_domain_when_no_default_suffix_is_used(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write(
                root / "clusters/home/infrastructure.yaml",
                """
                apiVersion: kustomize.toolkit.fluxcd.io/v1
                kind: Kustomization
                spec:
                  postBuild:
                    substitute:
                      OTHER_VALUE: example
                """,
            )
            write(
                root / "private/flux/home/example.yaml",
                """
                apiVersion: v1
                kind: ConfigMap
                data:
                  receiver: webhook-receiver.flux-system.svc.home-server.bronneberg.local
                """,
            )
            result = subprocess.run(
                ["bash", str(SCRIPT)],
                cwd=root,
                check=False,
                text=True,
                capture_output=True,
            )
            self.assertEqual(0, result.returncode, result.stderr)

    def test_fails_for_cluster_local_in_private_flux_manifests(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write(
                root / "clusters/home/infrastructure.yaml",
                """
                apiVersion: kustomize.toolkit.fluxcd.io/v1
                kind: Kustomization
                spec:
                  postBuild:
                    substitute:
                      KAIROS_CLUSTER_DOMAIN: home-server.bronneberg.local
                """,
            )
            write(
                root / "private/flux/home/example.yaml",
                """
                apiVersion: v1
                kind: ConfigMap
                data:
                  receiver: webhook-receiver.flux-system.svc.cluster.local
                """,
            )
            result = subprocess.run(
                ["bash", str(SCRIPT)],
                cwd=root,
                check=False,
                text=True,
                capture_output=True,
            )
            self.assertNotEqual(0, result.returncode)
            self.assertIn("must not use svc.cluster.local", result.stderr)
            self.assertIn("private/flux/home/example.yaml:4", result.stderr)

    def test_does_not_flag_longer_non_default_domains(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write(
                root / "private/flux/home/example.yaml",
                """
                apiVersion: v1
                kind: ConfigMap
                data:
                  receiver: webhook-receiver.flux-system.svc.cluster.local.example.com
                """,
            )
            result = subprocess.run(
                ["bash", str(SCRIPT)],
                cwd=root,
                check=False,
                text=True,
                capture_output=True,
            )
            self.assertEqual(0, result.returncode, result.stderr)

    def test_flags_cluster_local_with_query_terminator(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write(
                root / "private/flux/home/example.yaml",
                """
                apiVersion: v1
                kind: ConfigMap
                data:
                  receiver: http://webhook-receiver.flux-system.svc.cluster.local?probe=1
                """,
            )
            result = subprocess.run(
                ["bash", str(SCRIPT)],
                cwd=root,
                check=False,
                text=True,
                capture_output=True,
            )
            self.assertNotEqual(0, result.returncode)
            self.assertIn("private/flux/home/example.yaml:4", result.stderr)

    def test_flags_cluster_local_with_port_suffix(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write(
                root / "private/flux/home/example.yaml",
                """
                apiVersion: v1
                kind: ConfigMap
                data:
                  receiver: webhook-receiver.flux-system.svc.cluster.local:80
                """,
            )
            result = subprocess.run(
                ["bash", str(SCRIPT)],
                cwd=root,
                check=False,
                text=True,
                capture_output=True,
            )
            self.assertNotEqual(0, result.returncode)
            self.assertIn("private/flux/home/example.yaml:4", result.stderr)


if __name__ == "__main__":
    unittest.main()
