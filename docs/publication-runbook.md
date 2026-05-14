# Public Repository Publication Runbook

Use this runbook before changing the repository visibility to public.

## Local Checks

```bash
make public-check
```

The check runs CI-equivalent validation, Gitleaks scans, and public-redaction
rules for both the working tree and Git history. It is expected to fail before
the history rewrite if old commits contain private topology. Keep exact personal
denylist values in `.public-denylist.local`; that file is ignored so the public
repository does not reveal its own private patterns.

## SOPS And Age

The repository is configured for SOPS with age in `.sops.yaml`.

Create or rotate a local age identity:

```bash
mkdir -p .sops/age
age-keygen -o .sops/age/keys.txt
```

If you rotate the age key, replace the public recipient in `.sops.yaml`, then
run:

```bash
SOPS_AGE_KEY_FILE=.sops/age/keys.txt sops updatekeys private/*.sops.yaml
```

Encrypt a private overlay:

```bash
SOPS_AGE_KEY_FILE=.sops/age/keys.txt sops --encrypt --in-place private/home.sops.yaml
```

Decrypt for local inspection without writing plaintext into the repo:

```bash
SOPS_AGE_KEY_FILE=.sops/age/keys.txt sops decrypt private/home.sops.yaml
```

Back up `.sops/age/keys.txt` outside this repository before storing real
operational values. Decrypted files are ignored and must never be committed.

## History Rewrite

Do this only after the working tree is clean and the current content is ready
to become the new public `main`.

1. Create a private mirror backup:

   ```bash
   git clone --mirror git@github.com:example-org/home-server.git ../home-server-private-backup.git
   ```

2. Create `.public-replacements.local` with exact private string replacements.
   Use `git-filter-repo` replacement syntax, for example:

   ```text
   private-value==>example-value
   ```

3. Rewrite local history:

   ```bash
   git filter-repo --replace-text .public-replacements.local --refs main
   ```

4. Re-run:

   ```bash
   make public-check
   ```

5. Confirm no old topology remains:

   ```bash
   make check-history-redactions
   ```

6. Delete stale remote branches after confirming the mirror backup is usable.
   Keep only sanitized `main`.

7. Force-push sanitized `main`:

   ```bash
   git push --force-with-lease origin main
   ```

## GitHub Settings Before Public Visibility

- Enable secret scanning alerts.
- Enable push protection.
- Enable Dependabot alerts and Dependabot security updates.
- Protect `main` with required status checks.
- Confirm no public-runner workflow has kubeconfig, cluster credentials, or
  home-network deployment credentials.
- Change repository visibility only after the rewritten `main` passes all
  checks on GitHub Actions.
