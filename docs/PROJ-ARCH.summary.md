# noizu_jira — Architecture Summary

- **Shape:** stateless API client library for Jira Cloud (platform v3 + agile
  1.0 + enhanced software 1.0). No process tree, no app env, no global state.
- **Client:** immutable `Noizu.Jira.Client` struct (auth tuple
  basic/oauth, `site`/`cloud_id`, `req_opts` → Req, retry overrides) passed
  explicitly to every call.
- **Request path:** resource module → (ADF wrap / Pagination stream) →
  `Noizu.Jira.Request` (URL + in-house query encoding, manual
  `Authorization` header, Req with `retry: false`) → bounded 429/503 loop
  honoring `Retry-After` → decoded map or `%Noizu.Jira.Error{}`.
- **Responses:** decoded JSON maps, never structs; errors mirror Jira's
  error-collection shape; transport failures → `status: nil`, never retried.
- **Streams:** `Stream.resource` walker; offset / nextPageToken / bare-array
  termination, defensive about absent `total`/`isLast` and legal empty pages;
  raise `Noizu.Jira.Error` on page failure (no error channel in a lazy Stream).
- **Excluded by design:** legacy `/search`, offset board-issues endpoint,
  OAuth token lifecycle, Server/Data Center APIs, response structs.
- **Stack:** Elixir ~> 1.15, Req ~> 0.7, Jason ~> 1.4; Plug (test), ExDoc (dev).
- **Testing:** offline via `Req.Test` plugs and fake credentials; query/retry
  behavior pinned by tests.
- Details: `arch/request-pipeline.md`, `arch/streaming.md`,
  contract `docs/API-CONTRACT.md` (§10 decision log).
