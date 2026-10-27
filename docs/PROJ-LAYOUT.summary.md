# noizu_jira — Layout Summary

```
jira/
├── lib/noizu/jira/     # Client library (resources, agile, client/request/pagination/error/adf) → layout/lib.md
├── test/               # Req.Test-stubbed unit suites + support → layout/test.md
├── docs/               # Hand-written docs: API-CONTRACT, layout/arch/threats detail (+ summaries)
├── doc/                # Generated ExDoc output (gitignored)
├── .github/            # CI workflow (3-lane Elixir matrix)
├── .meta/              # doc-pointers store (pointers.yaml)
├── mix.exs             # Project/deps/ex_doc/Hex package
├── mix.lock            # Locked dep versions
├── .formatter.exs      # mix format inputs
├── .gitignore          # Standard Mix ignores
├── CHANGELOG.md        # Dated work log
├── README.md           # Quickstart
└── LICENSE             # MIT
```

Runtime deps: `req ~> 0.7`, `jason ~> 1.4`. Test-only: `plug`. Dev-only: `ex_doc`.
No config files, no application env, no required local setup.
