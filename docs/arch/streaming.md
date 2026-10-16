# noizu_jira — Streaming and Pagination

How `*_stream` functions walk multi-page listings. Machinery lives in
Noizu.Jira.Pagination (`@moduledoc false`); semantics are contractual —
`docs/API-CONTRACT.md` §5.

## Why it exists

Jira Cloud runs **two paging models at once**, and some list endpoints return
bare arrays:

- **Offset** — `{startAt, maxResults, total, isLast, values|comments|worklogs|issues: [...]}`
- **Token** — `{items..., isLast, nextPageToken?}` (JQL `search/jql`, enhanced
  board issues)
- **Array** — plain list (user search)

Atlassian documents that `total` and `isLast` are absent on some operations and
that an **empty page is legal and non-final** — so termination rules are
defensive.

## Structure

Every stream is a `Stream.resource/3` over three injected functions:

1. `fetch/1` — performs the first page request (a normal resource call).
2. `items_fun/1` — extracts the items list from the page (items key differs
   per endpoint: `values`, `comments`, `worklogs`, `issues`, or none).
3. `next/1` — decides continuation, returning `{:more, thunk}` or `:done`:

   - `offset_next/3`: stop on empty items; stop on `isLast == true`; stop when
     `total` present and `startAt + length(items) >= total`; otherwise refetch
     at `startAt + length(items)`.
   - `token_next/2`: follow `nextPageToken` until absent or empty.
   - `array_next/4`: stop on empty page or when a page is shorter than
     `max_results`.

Each step emits the page's items before fetching the next, so consumers see a
plain `Enumerable.t()` of items with no envelope noise.

## Error convention

A lazy `Stream` has no error channel, so **page failures raise**
`%Noizu.Jira.Error{}` mid-iteration (first page included). This is a
documented contract decision: swallowing the error would corrupt
`Enum.reduce` results. Callers needing error tuples page manually with the
per-call `{:ok, page}` functions.

## Per-endpoint wiring

| Stream | Pager |
|---|---|
| `Search.stream/3` | token (`nextPageToken`) |
| `Comments.stream/3`, `Worklogs.stream/3`, `Projects.stream/3`, `Statuses.stream/2` | offset |
| `Agile.Boards.issues_stream/3` | token (enhanced `/rest/software/1.0` endpoint) |
| `Agile.Sprints.issues_stream/3` | offset |
| `Users.stream/3` | array |

`Fields.list/1` deliberately has no stream — Atlassian is mid-migration
between a flat array and a paginated map, so there is no stable shape to page.
