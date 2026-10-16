# noizu_jira — Supply Chain (Hex Dependencies)

The library's dependency exposure. Grounding: `mix.exs` deps, `mix.lock`
(SHA-256 pins), repo state (no CI, pre-initial-commit).

## Dependency tree

**Runtime (ships to consumers):**

| Dep | Lock | Role |
|---|---|---|
| `req` | 0.7.5 | HTTP client; multipart streaming for attachments |
| `jason` | 1.4.5 | JSON encode/decode |

Transitive runtime closure (all via Req): `finch` 0.24.0, `mint` 1.11.0,
`hpax` 1.1.0, `mime` 2.0.7, `nimble_options` 1.1.1, `nimble_pool` 1.1.0,
`telemetry` 1.4.2 — a small, mainstream tree, all from the public `hexpm`
repository.

**Test-only:** `plug` 1.20.3 (Req.Test stubs). **Dev-only:** `ex_doc` 0.40.4
(+ makeup family, earmark_parser). Neither ships to consumers.

Version constraints are deliberately loose (`~> 0.7`, `~> 1.4`); `mix.lock`
pins the exact versions and SHA-256 checksums, so consumer builds are
reproducible even against a mutable Hex registry.

## Findings and posture

- **T-010 (Medium, Supply chain, Partially mitigated):** the classic Hex
  risks — a compromised upstream package, a typosquat, or a malicious new
  release pulled in by a loose `~>` constraint on a future `deps.update`.
  Mitigations in place:
  - `mix.lock` pins every package + checksum; builds without the lock are
    not the supported flow.
  - Minimal tree: two runtime deps, no umbrella of unknown maintainers.
  - Package published from `files:` in `mix.exs` (lib + docs only) — no
    build scripts, no NIFs, no escript entry points in the dependency set.
  Gaps (honest accounting):
  - **No CI exists yet** (repo is pre-initial-commit): no automated
    `mix hex.audit`, no Dependabot/renovate, no lockfile-diff review gate.
    Supply-chain review is currently a manual duty on every dependency bump.
  - Hex packages are checksummed but the trust root is the registry itself;
    a registry compromise is out of this library's control (standard Hex
    posture).
  *Recommended mitigations:* when the repo goes public, add CI running
  `mix deps.unlock --check-unused`, `mix hex.audit`, and a lockfile-review
  requirement on dependency PRs.
- **Consumer inheritance (residual):** applications depending on
  `noizu_jira` inherit Req's tree and its advisories; semver-bounded bumps
  flow through lockfile updates, so consumers should audit their own lock,
  not this one's, for final posture.

## Explicitly not exposed

- No NIFs, no port drivers, no `System.cmd`, no file writes anywhere in
  `lib/` (the only filesystem read is the caller-supplied attachment path
  streamed for upload).
- No `Code.eval`, no dynamic module compilation, no config-file loading
  (no `config/` directory, no application env reads).
