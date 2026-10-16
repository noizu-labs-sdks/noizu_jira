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
- Sleep: `Retry-After` (seconds) honored **exactly when present**;
  otherwise exponential backoff from 250 ms, doubling, **capped at 30 s**,
  with 0.7–1.3 jitter. The `sleep` fun is injectable.

## Findings

- **T-005 (Low, Denial of service, Open):** the `Retry-After` path has **no
  clamp**:
  - A **negative** value (`Retry-After: -1`) parses to a negative integer and
    reaches `Process.sleep/1`, which raises `FunctionClauseError` (verified) —
    crashing the calling process rather than returning an error.
  - A **huge** value (`Retry-After: 999999999`) hangs the calling process for
    the full duration; the 30 s `max_sleep_ms` cap applies only to the
    backoff path, not here.
  Exploitation requires a hostile or broken responder in the TLS path
  (Atlassian itself, a corporate TLS-inspecting proxy, or a `plug:` test
  stub); a network MITM cannot forge responses without breaking certificate
  verification. *Recommended mitigation:* clamp the parsed value to
  `[0, max_sleep_ms]` (or a dedicated `:max_retry_after_ms`), treating
  non-positive as "use backoff".
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
