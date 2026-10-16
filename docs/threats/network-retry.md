# noizu_jira — Retry Behaviour and Network Availability

What the 429/503 retry loop does, and what a hostile or broken endpoint can
do with it. Grounding: `Request.run/3`, `retry/6`, `retry_after_ms/1`,
contract §7.

## The policy

- Only **429 and 503** are retried; transport failures and every other status
  return immediately. Req's own retry machinery is disabled (`retry: false`)
  so there is exactly one retry owner (no amplification from stacked
  policies).
- Bounded: `max_attempts: 3` total tries by default.
- Sleep: `Retry-After` (seconds) honored **when present, clamped to
  `[0, max_sleep_ms]`** (negative → 0, huge → the cap, unparseable → backoff);
  otherwise exponential backoff from 250 ms, doubling, **capped at 30 s**,
  with 0.7–1.3 jitter. The `sleep` fun is injectable.

## Findings

- **T-005 (Low, Denial of service, Mitigated):** the `Retry-After` path had
  **no clamp**: a **negative** value (`Retry-After: -1`) reached
  `Process.sleep/1` and raised `FunctionClauseError`, crashing the calling
  process (verified), and a **huge** value (`Retry-After: 999999999`) hung
  it for the full duration — the 30 s `max_sleep_ms` cap applied only to
  the backoff path, not here.
  Exploitation requires a hostile or broken responder in the TLS path
  (Atlassian itself, a corporate TLS-inspecting proxy, or a `plug:` test
  stub); a network MITM cannot forge responses without breaking certificate
  verification. *Mitigation:* the parsed value is clamped to
  `[0, max_sleep_ms]` — negative → 0, oversized → the cap (the cap follows
  the caller's `:max_sleep_ms` override). Tests: the `(T-005)` entries in
  `test/noizu/jira/retry_test.exs` (negative clamps to 0 via the default
  `Process.sleep/1` path, huge clamps to the default and a custom cap,
  garbage falls back to exponential backoff).
- **Quota self-DoS (mitigated by design):** retries are bounded at 3 total
  tries and sleep between them, so the library cannot amplify load against
  Atlassian burst limits beyond 3× per call; exhausted retries surface the
  final 429/503 as a normal error tuple.
- **No retry on transport errors (mitigated):** connection failures,
  timeouts, and TLS errors return `{:error, %Error{status: nil}}` — a flaky
  network cannot cause credential re-sending loops or unbounded call
  amplification by the library itself.

## Caller-visible invariants

Streams page lazily: each page fetch inherits the same retry policy, so a
paged walk over a rate-limited tenant sleeps per page but never loops
endlessly; mid-stream failure raises `%Noizu.Jira.Error{}` (documented
convention, contract §5).
