# Noizu.Jira

Elixir client for the [Jira Cloud REST API](https://developer.atlassian.com/cloud/jira/platform/rest/v3/) — platform v3 plus the Jira Software agile API.

- Auth: Basic (email + API token) or OAuth 2.0 3LO (bearer token + cloud id)
- Issues, JQL search, transitions, comments, worklogs, attachments, issue links, projects, users, fields, issue types, statuses
- Agile: boards, sprints, board/sprint issues
- Pagination: per-call pages (`{:ok, page}`) or lazy `*_stream` enumerables (both offset and `nextPageToken` styles)
- Errors: `{:error, %Noizu.Jira.Error{}}` mirroring Jira's error-collection shape
- Rate limits: bounded 429/503 retries honoring `Retry-After`

Full endpoint inventory, behavioral rules, and the decision log live in [`docs/API-CONTRACT.md`](docs/API-CONTRACT.md).

## Installation

```elixir
def deps do
  [
    {:noizu_jira, "~> 0.1.0"}
  ]
end
```

## Quickstart

Basic auth against `https://<site>.atlassian.net`:

```elixir
client =
  Noizu.Jira.Client.new(
    auth: {:basic, "you@example.com", System.fetch_env!("JIRA_API_TOKEN")},
    site: "example.atlassian.net"
  )

{:ok, issue} = Noizu.Jira.Issues.get(client, "PROJ-123", fields: ["summary", "status"])
```

OAuth 2.0 3LO (pass the access token and the cloud id from
`https://api.atlassian.com/oauth/token/accessible-resources`):

```elixir
client =
  Noizu.Jira.Client.new(
    auth: {:oauth, access_token},
    cloud_id: "11112222-3333-4444-5555-666677778888"
  )
```

Creating an issue (plain text is wrapped in Atlassian Document Format for you where needed):

```elixir
Noizu.Jira.Issues.create(client, %{
  "project" => %{"key" => "PROJ"},
  "issuetype" => %{"name" => "Task"},
  "summary" => "Ship it",
  "description" => Noizu.Jira.ADF.doc("First line.\n\nSecond paragraph.")
})
```

Searching with JQL and paging lazily (works across both pagination styles):
```elixir
Noizu.Jira.Search.stream(client, "project = PROJ ORDER BY created DESC", max_results: 50)
|> Stream.map(& &1["key"])
|> Enum.take(500)
```

Comments, transitions, worklogs, attachments:

```elixir
Noizu.Jira.Comments.add(client, "PROJ-123", "done in #4482")
Noizu.Jira.Transitions.perform(client, "PROJ-123", "31")
Noizu.Jira.Worklogs.add(client, "PROJ-123", time_spent: "1h 30m", comment: "pairing")
Noizu.Jira.Attachments.add(client, "PROJ-123", "/tmp/trace.log")
Noizu.Jira.Agile.Boards.issues_stream(client, 42) |> Stream.map(& &1["key"])
```

Errors and rate limits:

```elixir
case Noizu.Jira.Issues.get(client, "NOPE-1") do
  {:ok, issue} -> issue["fields"]["summary"]
  {:error, %Noizu.Jira.Error{status: 404}} -> :missing
  {:error, %Noizu.Jira.Error{field_errors: fields}} -> {:invalid, fields}
end
```

429/503 responses are retried automatically (bounded, honoring `Retry-After`); tune with `retry: [max_attempts: 5, base_sleep_ms: 500]` on `Client.new/1`. Transport failures and non-retryable statuses return `{:error, error}` immediately.

## Status

v0.1.0. Changelog in [`CHANGELOG.md`](CHANGELOG.md). MIT licensed. Generated docs: `mix docs`.
