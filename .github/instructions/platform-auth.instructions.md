---
applyTo: "clusters/home/infrastructure/oauth2-proxy/**,clusters/home/infrastructure/monitoring/**,private/flux/home/oauth2-proxy*,scripts/check-oauth2-github-policy.sh"
---

# Platform Authentication Invariants

These rules apply to shared authentication and Grafana routing work regardless
of the selected agent or skill. Follow the [platform instructions](home-platform.instructions.md).
The existing `make auth-policy-check` enforces the statically decidable parts;
its success does not replace the affected-host verification below.

## OAuth2 and Traefik

- Keep `clusters/home/infrastructure/oauth2-proxy/github-oauth.yaml` on
  `github-oauth-errors.spec.errors.query: /oauth2/sign_in?rd={url}`.
- Do not change that Traefik error middleware query to `/oauth2/start?rd={url}`.
  Traefik preserves the original 401/403 status for error middleware responses;
  oauth2-proxy's `/oauth2/start` returns a redirect body under that preserved
  401, which makes browsers show the small `Found` page instead of the login
  page.
- The oauth2-proxy sign-in template can submit to `/oauth2/start`; the Traefik
  error middleware itself must stay on `/oauth2/sign_in`.
- Any future shared auth-flow change must be explicitly requested by the user
  and verified against every protected host class it affects. At minimum, curl
  an unauthenticated protected host and confirm it returns the identity gateway
  HTML rather than `Found`, then curl the same-host `/oauth2/start?...` URL and
  confirm it returns a real 302 to GitHub.
- For Grafana behind oauth2-proxy, keep
  `grafana.auth.proxy.enable_login_token: false` and
  `grafana.auth.login_cookie_name: grafana_auth_proxy_session`.
- Persist Grafana's database so users, preferences, and local session state are
  not reset when the Grafana pod is recreated.
- Keep Grafana browser page routes on the normal OAuth sign-in chain, but route
  the `/api` prefix through forward auth only. Grafana API 401/403 responses
  must not be converted into oauth2-proxy sign-in pages, because the frontend
  interprets those redirects as repeated login failures.
- Apply the dedicated Grafana runtime values layer after private values so this
  routing and persistence policy cannot be accidentally overridden.
