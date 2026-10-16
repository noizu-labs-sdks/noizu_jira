# Changelog

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
