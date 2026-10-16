# noizu_jira — Test Layer

Breakdown of `test/`. All HTTP is stubbed via `Req.Test` (the `plug:` opt on
`Noizu.Jira.Client`); no test talks to a live Jira instance.

```
test/
├── test_helper.exs              # ExUnit bootstrap
├── support/
│   └── test_support.ex          # Shared fixtures/helpers (compiled into :test)
└── noizu/jira/
    ├── adf_test.exs             # ADF.doc/1: paragraphs, hard breaks, pass-through
    ├── agile_test.exs           # Boards + sprints incl. enhanced board issues
    ├── attachments_test.exs     # Multipart upload, no-check header, content/raw
    ├── client_test.exs          # Client.new validation, site normalization
    ├── comments_test.exs        # Comment CRUD + paging
    ├── error_test.exs           # Error.decode/2, message/1 rendering
    ├── issue_links_test.exs     # link/5 builder + create/get/delete
    ├── issues_test.exs          # Issue CRUD + bulk create
    ├── metadata_test.exs        # Fields / issue types / statuses modules
    ├── pagination_test.exs      # offset_next / token_next / array_next termination
    ├── projects_test.exs        # Project search/get
    ├── query_test.exs           # Pins exact query strings (csv vs multi styles)
    ├── retry_test.exs           # 429/503 policy: Retry-After, backoff, exhaustion
    ├── search_test.exs          # search/jql body + token stream
    ├── transitions_test.exs     # list + perform
    ├── users_test.exs           # myself/get/search + array stream
    └── worklogs_test.exs        # Worklog add/update/delete
```

Notes:

- `query_test.exs` and `retry_test.exs` pin the contract's behavioral guarantees
  (`docs/API-CONTRACT.md` §5a, §7) — keep them in sync with any `Request` change.
- `pagination_test.exs` covers the defensive termination rules (§5): absent
  `total`/`isLast`, trailing empty pages, token exhaustion.
- `elixirc_paths(:test)` in `mix.exs` compiles `test/support` into the test
  environment.
