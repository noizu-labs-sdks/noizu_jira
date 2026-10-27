# AGENT-README

> Orientation for AI coding agents working in this repo. Human docs: README.md (plus docs/API-CONTRACT.md and docs/THREAT-MODEL.md).

## Type

elixir-lib (Hex package, API client)

## Purpose

Elixir client for the Jira Cloud REST API (platform v3) plus the Jira Software agile API — issues, JQL search, transitions, comments, worklogs, attachments, links, projects, users, fields, boards, sprints.

## Stack

Elixir ~> 1.15. Deps: `req` (~> 0.7), `jason`; `plug` test-only. Basic (email + API token) or OAuth 2.0 3LO auth; ADF helper (`Noizu.Jira.ADF`) wraps plain text; offset- and `nextPageToken`-style pagination with lazy `*_stream` variants; bounded 429/503 retries honoring `Retry-After`.

## Dev mode

```bash
mix deps.get
mix test
```

## Ports / URLs

- none (library/CLI)

## Tests

```bash
mix test    # stubbed; no live network
```

## Gotchas

- `JIRA_API_TOKEN` env feeds the Basic-auth quickstart; `:site` takes a bare subdomain (`"acme"`) or full host — userinfo, ports, paths, and non-Atlassian hosts are rejected (tests/proxies pass `:base_url` explicitly).
- The client struct redacts credentials in `inspect/1` (at most the email + 4-char token prefix) — keep it that way.
