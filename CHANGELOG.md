# Changelog

## 2026-10-28
- docs: add AGENT-README.md (agent orientation)

## Unreleased

- Doc sweep 2026-10-27: added `docs/PROJ-SCHEMA.md` (+ summary) covering the
  client/error/ADF data shapes (no relational store — ERD n/a); layout tree
  now lists the full docs subtree, `.github/`, and `.meta/`; threat model
  and supply-chain notes updated for the 3-lane CI matrix (Elixir
  1.15/1.18/1.20); doc-pointer store re-anchored for the T-001 `Inspect`
  marker (pointer `fdcc43bd-842b-59a3-aca3-c12e70026829`).

- Uploads compile and run warning-free across the supported Elixir range
  (1.15–1.20): `File.stream!/3`'s argument order changed in 1.16
  (`(path, modes, line_or_bytes)` → `(path, line_or_bytes, modes)`, the old
  order warns at runtime on newer compilers), so a compile-time branch now
  picks the signature matching the compiling version; the 64 KiB lazy chunked
  stream behaviour is identical on both. CI gained an Elixir 1.20/OTP 29 lane
  and a >64 KiB multi-chunk upload test guards the streaming path.

Security-hardening pass (threat model: `docs/THREAT-MODEL.md`).

- Credentials are redacted from `inspect/1` of `Noizu.Jira.Client` — at most the basic email and a 4-character token prefix appear; the API token / OAuth access token never render (T-001).
- `Client.new/1` auth-validation errors describe the offending value's shape (e.g. "3-element tuple") instead of interpolating `inspect/1`, so malformed auth tuples can no longer leak real credentials into logs (T-002).
- `:site` is validated: a bare subdomain (`"acme"` → `acme.atlassian.net`) or a `<sub>.atlassian.net` host (case-insensitive); userinfo (`@`), ports, paths, query strings, and foreign hosts are rejected — a hostile value could otherwise receive the `Authorization` header (T-003). New `:base_url` option is the explicit escape hatch for proxies/tests (https required off `localhost`/`127.0.0.1`; `Req.Test` stubs work through it).
- `Retry-After` is clamped to `[0, max_sleep_ms]`: a negative value no longer crashes `Process.sleep/1`, a huge value no longer hangs the caller (the cap follows the `:max_sleep_ms` override), and unparseable values fall back to exponential backoff (T-005).
- `Noizu.Jira.Search` moduledoc now warns that JQL is sent verbatim (no parameterized API form) and callers must not interpolate untrusted input (T-008, accepted risk, documented).
- CI: GitHub Actions workflow (push/PR on `develop`/`stage`/`main`) with an Elixir 1.15/OTP 25 + 1.18/OTP 27 matrix — `mix format --check-formatted`, `mix compile --warnings-as-errors`, `mix test`, `mix hex.audit`, deps/`_build` cached (T-010 audit leg).
- Attachment upload streams via `File.stream!/3`'s chunk-size third argument, restoring compatibility with Elixir 1.15 (the read-ahead-bytes second argument requires >= 1.16); tests normalized so patterns avoid pin-inside-`<>` concatenation, which older Elixir rejects at compile time.
- Threat model updated: T-001/T-002/T-003/T-005 moved to Mitigated with regression-test evidence; docs (README, API-CONTRACT, layout/arch notes) aligned with the new `:site` grammar and retry clamp.

- Repository moved to the `noizu-labs-sdks` GitHub org; `source_url` and hex package links updated in `mix.exs`.

## 0.1.0 — 2026-10-17

Initial release.

- Contract-first client for the Jira Cloud REST API platform v3 (`docs/API-CONTRACT.md`).
- Auth: Basic (email + API token) and OAuth 2.0 3LO (bearer against `api.atlassian.com/ex/jira/<cloudId>`).
- Resources: issues (CRUD + bulk create), JQL search via `POST /search/jql` + approximate count, transitions, comments, worklogs, attachments (streamed multipart, `X-Atlassian-Token: no-check`), issue links, projects, users, fields, issue types, statuses.
- Agile API: boards (create/get/delete/list), sprints (CRUD), board issues via the enhanced `/rest/software/1.0` token-paginated endpoint, sprint issues (offset).
- Pagination: `{:ok, page}` per call plus lazy `*_stream` helpers covering both offset and `nextPageToken` styles, with defensive termination (handles absent `total`/`isLast` and legal empty pages).
- Query encoding: built in-house per parameter (comma-joined `fields`/`expand`/`properties`; repeated `keys`/`status` on project search), sidestepping the HTTP client's `key[]=` list encoding.
- Errors: `{:error, %Noizu.Jira.Error{}}` mirroring the Jira error-collection shape (`messages`, `field_errors`, `status`).
- Rate limits: bounded retries on 429/503 honoring `Retry-After` exactly, exponential backoff with jitter otherwise, injectable sleep.
- Requires Req `~> 0.7` (attachment uploads use `form_multipart` streaming).
- Minimal Atlassian Document Format helper (`Noizu.Jira.ADF.doc/1`) for plain text.
- Docs: project layout (`docs/PROJ-LAYOUT.md`), architecture (`docs/PROJ-ARCH.md`), and threat model (`docs/THREAT-MODEL.md`) with detail files under `docs/layout/`, `docs/arch/`, `docs/threats/` plus `.summary.md` companions; public API annotated with doc pointers (`.meta/pointers.yaml`).
- Doc-pointer cleanup: removed duplicate `@doc` stub blocks ("redefining @doc" warnings), normalized markers to `# 〚🔧:uuid〛` comments, added ex_doc extras (`#1`; released to stage/main via `#2`/`#3`).
