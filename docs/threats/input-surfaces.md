# noizu_jira — Input Surfaces: JQL, Bodies, Attachments, Server Data

Everything the library sends and receives that is not URL construction.
Grounding: `Search`, `Issues`, `Comments`, `Worklogs`, `Attachments`,
`ADF`, `Error`.

## JQL (search and count)

- **T-008 (Low, Information disclosure, Accepted):** JQL is accepted verbatim
  and sent inside the JSON body of `POST /search/jql`. Jira's search API has
  no bind parameters, so string-composed JQL is the norm for every client;
  "injection" here means **JQL logic injection only** — a crafted query can
  read whatever the *token itself* is allowed to read, no more. There is no
  escalation path to other endpoints or write access. Host guidance: do not
  interpolate untrusted strings into JQL; prefer exact keys/ids
  (`key in ("PROJ-1", "PROJ-2")`). Accepted because the blast radius equals
  the credential's own permission scope and the API offers no parameterized
  alternative.

## JSON bodies

Field maps (`Issues.create/edit`, `Transitions.perform`, `IssueLinks.create`)
are passed through as-is and JSON-encoded by Jason — no template, no eval, no
code execution from body content. Where the API requires Atlassian Document
Format, `ADF.doc/1` splits text on newlines only and JSON-encodes the result;
text content cannot break out of the JSON string encoding. No finding.

## Attachments

Upload (`Attachments.add/4`) is `multipart/form-data` streamed from disk in
64 KiB chunks (constant memory) with the mandatory `X-Atlassian-Token:
no-check` header — that header disables Atlassian's CSRF check for the
endpoint, per Atlassian's own API requirement; API-token auth is the actual
protection, and the library cannot be tricked into omitting auth.

- **T-006 (Low, Tampering, Open/documented):** the multipart part filename is
  the source path's `basename` or the `filename:` opt, inserted into the
  `Content-Disposition` header without sanitization. A path/filename
  containing quotes or control characters could mangle the part header.
  Caller-controlled input only (it names the host's own file), so impact is
  a malformed upload, not credential or data exposure. *Recommended
  mitigation:* document/validate allowed filename characters when `filename:`
  is passed.
- **T-007 (Low, DoS, Open/documented):** `Attachments.content/3` returns the
  entire attachment as one binary — no size cap. A huge or hostile-served
  attachment can exhaust memory in the host process. *Recommended
  mitigation:* document the expectation (metadata via `get/3` first, size
  limit `content.size`) or offer a streaming variant.
- Path traversal on issue keys / attachment ids is prevented by
  `encode_segment/1` (control, T-012).

## Server-controlled data (responses)

- Response bodies are decoded by Jason into plain maps and returned as data —
  never eval'd, never interpolated into code. No finding.
- **T-009 (Low, Information disclosure, Accepted):** `%Noizu.Jira.Error{}`
  retains the full raw response `body` so callers can debug. If a host logs
  error structs wholesale, Jira content (issue text, user identifiers in
  error messages) reaches logs. Accepted host responsibility: redact before
  logging; the library does not log itself.
- Response headers: only `Retry-After` is acted on — see
  `threats/network-retry.md` (T-005). All other headers, including
  `X-RateLimit-*`, are ignored.
