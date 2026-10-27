# noizu_jira — Schema Summary

- **No relational store, no KV, no config files, no data files** — ERD
  sections not applicable; the structured data is the shapes below.
- **`%Client{}`** (config): `auth` (`{:basic, email, token}` | `{:oauth,
  token}`, required), `site` (validated grammar, T-003), `cloud_id` (oauth),
  `base_url` (https escape hatch), `req_opts` (default `[]`), `retry`
  (defaults `max_attempts: 3, base_sleep_ms: 250, max_sleep_ms: 30_000`).
  Built by `new/1`, immutable, passed explicitly.
- **`%Error{}`**: `status` (`nil` ⇒ transport failure, never retried),
  `messages`, `field_errors` (from Jira error-collection bodies), `reason`,
  `body` (raw — host redacts before logging, T-009). Streams raise it.
- **ADF document**: `%{"type" => "doc", "version" => 1, "content" =>
  [paragraphs]}`; `doc/1` builds from plain text or passes an ADF map
  through.
- **Interfaces**: request/response contract lives in `docs/API-CONTRACT.md`
  (§4 inventory, §5a query styles `:csv`/`:multi`, §6 errors, §7 retry);
  bodies are decoded JSON maps, no response structs.
- **Test data**: `Req.Test` plugs + fake credentials only; no fixture files.

```mermaid
graph LR
    H[Host options] -->|new/1| C[%Client{}]
    C --> REQ[Request envelope]
    B[Body / ADF doc] --> REQ
    REQ --> J[(Jira Cloud API)]
    J -->|2xx| OK[decoded map]
    J -->|failure| E[%Error{}]
```

Details: [PROJ-SCHEMA.md](PROJ-SCHEMA.md).
