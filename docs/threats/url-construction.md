# noizu_jira — URL Construction: site / cloud_id

Where request URLs come from and what a hostile value in the client
configuration can do. Grounding: `Client.base_url/1`, `normalize_site/1`,
`Request.encode_segment/1`, `Request.params_query/1`.

## How URLs are assembled

```
base_url <> path <> "?" <> query
```

- **Basic auth:** `base_url = "https://" <> site` — `normalize_site/1`
  lowercases the value, strips a `https://` / `http://` prefix and a
  trailing `/`, then enforces the grammar: a bare subdomain
  (`acme` → stored as `acme.atlassian.net`) or a full host matching
  `^[a-z0-9][a-z0-9-]*\.atlassian\.net$` (case-insensitive). Everything
  else — userinfo (`@`), ports, paths, query strings, foreign hosts, empty
  values — raises `ArgumentError` (message never echoes the input).
  The scheme is always re-applied as `https://` (no downgrade attack).
- **Escape hatch:** `:base_url` overrides the URL entirely (proxies, tests).
  It must be an absolute URL with an `https` scheme; `http` is accepted
  only for `localhost`/`127.0.0.1`; no userinfo, path, query, or fragment.
  Req.Test stubs work through it unchanged.
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

- **T-003 (Medium, Information disclosure/Spoofing, Mitigated):** because
  `:site` was an arbitrary string re-attached to `https://`, a hostile or
  mistaken value redirected **every request — including the `Authorization`
  header — to an attacker-controlled host**: `site: "evil.example.com"`, or
  the userinfo trick `site: "example.atlassian.net@evil.example.com"`, which
  still *looked* legitimate in logs/config. *Mitigation:* `:site` grammar
  enforced (bare subdomain or `<sub>.atlassian.net`; userinfo, ports, paths,
  queries, and foreign hosts rejected with a fixed `ArgumentError`), plus
  the explicit `:base_url` escape hatch for proxies/tests (https off
  loopback). Tests: `site validation (T-003)` in
  `test/noizu/jira/client_test.exs` — asserts `"x.atlassian.net@evil.com"`,
  `"evil.com"`, `"acme.atlassian.net:444"`, `"acme.atlassian.net/x"` are
  rejected and `"acme"` / `"acme.atlassian.net"` are accepted, and that
  Req.Test stubs still run through `:base_url`.
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

DNS rebinding and Atlassian-side behavior. Proxies: the supported route is
the explicit `:base_url` option (https required off loopback); with
`req_opts` the host *can* additionally point Req at a proxy or weaken TLS
(`verify: :verify_none`) — the library permits but never sets these; doing
so is a host-side decision and out of this model's boundary.
