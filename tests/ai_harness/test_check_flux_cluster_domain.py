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
    def test_accepts_configured_home_cluster_domain(self):
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
            self.assertIn("svc.home-server.bronneberg.local", result.stdout)

    def test_fails_when_cluster_domain_is_missing(self):
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
            result = subprocess.run(
                ["bash", str(SCRIPT)],
                cwd=root,
                check=False,
                text=True,
                capture_output=True,
            )
            self.assertNotEqual(0, result.returncode)
            self.assertIn("Unable to determine the home cluster domain.", result.stderr)

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
            self.assertIn("Expected service suffix: svc.home-server.bronneberg.local", result.stderr)
            self.assertIn("private/flux/home/example.yaml:4", result.stderr)


if __name__ == "__main__":
    unittest.main()
