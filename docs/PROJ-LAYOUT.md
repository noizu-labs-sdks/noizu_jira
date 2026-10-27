# noizu_jira — Project Layout

`noizu_jira` is an Elixir Hex library: an API client for the Jira Cloud REST
API (platform v3 + Jira Software agile API). No application, no runtime
processes, no persistent state — a thin, stateless client library
(`docs/API-CONTRACT.md` is the behavioral reference).

```
jira/
├── lib/                            # Source (the Hex package ships this)
│   └── noizu/jira/                 # Client library → [layout/lib.md](layout/lib.md)
│       ├── jira.ex                 #   Namespace moduledoc (entry point)
│       ├── client.ex               #   Client struct: auth, site/cloud_id, req_opts, retry
│       ├── request.ex              #   Internal HTTP executor + retry loop
│       └── error.ex                #   %Noizu.Jira.Error{} exception
├── test/                           # Req.Test-stubbed unit tests → [layout/test.md](layout/test.md)
│   ├── support/test_support.ex     #   Stub plug helpers (fake creds only)
│   └── noizu/jira/*_test.exs       #   Per-module suites (query/retry/pagination pin the contract)
├── docs/                           # Hand-written docs (shipped in the Hex package)
│   ├── API-CONTRACT.md             #   Endpoint inventory, behavior, decision log
│   ├── PROJ-LAYOUT.md              #   This file
│   ├── PROJ-LAYOUT.summary.md      #   Tree-only quick reference
│   ├── PROJ-ARCH.md                #   Architecture overview (+ PROJ-ARCH.summary.md)
│   ├── PROJ-SCHEMA.md              #   Data-shape reference (client/error/ADF) (+ summary)
│   ├── THREAT-MODEL.md             #   Threat model, vulnerability register (+ summary)
│   ├── layout/                     #   Per-layer detail (lib.md, test.md)
│   ├── arch/                       #   Request pipeline, streaming detail
│   └── threats/                    #   Per-concern threat detail (5 files)
├── doc/                            # mix docs output (GENERATED, gitignored — not "docs/")
├── .github/workflows/ci.yml        # CI: 3-lane Elixir matrix (1.15/1.18/1.20), format + compile + test + hex.audit
├── .meta/pointers.yaml             # doc-pointers store (UUID markers in source comments)
├── mix.exs                         # Project, deps, ex_doc groups, Hex package config
├── mix.lock                        # Locked dep versions (supply-chain pin)
├── .formatter.exs                  # mix format inputs (mix, config, lib, test)
├── .gitignore                      # Standard Mix ignores (_build, deps, doc, cover, tmp)
├── CHANGELOG.md                    # Dated work log (0.1.0 initial release + unreleased)
├── README.md                       # Quickstart + install
└── LICENSE                         # MIT
```

## Key facts

- **`doc/` vs `docs/`**: `doc/` is generated ExDoc output (gitignored);
  `docs/` is hand-written and **included in the Hex package** (`files:` in
  `mix.exs` lists `docs`). Anything placed in `docs/` ships to Hex.
- **No `.envrc` / `.env.example`**: the library reads no configuration files.
  Credentials are caller-supplied per client (`auth:` tuple); the README
  quickstart expects `JIRA_API_TOKEN` from the *host application's* env.
- **Deps** (`mix.exs`): runtime `req ~> 0.7` (multipart streaming for
  attachments) + `jason ~> 1.4`; test-only `plug ~> 1.16`; dev-only
  `ex_doc ~> 0.34`. Versions pinned in `mix.lock`.
- **No `config/` directory**: no application env, no global state — every
  setting lives on the `Noizu.Jira.Client` struct.

## Files requiring setup

None. As a library it has no required local configuration; tests run offline
(`Req.Test` stubs, fake credentials only).
