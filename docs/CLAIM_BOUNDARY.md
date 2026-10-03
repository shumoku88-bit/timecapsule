# Claim boundary

This first TimeCapsule milestone establishes only the behavior of the pure state
machine.

## Current semantics

The core accepts two commands:

- `Seal(deadline)`
- `Release(observed_at)`

The intended transition is:

```text
Unsealed
  -- Seal(d) -->
Waiting(d)
  -- Release(t), t >= d -->
Released(d, t)
```

The following behaviors are part of the pure contract:

- `Release` is refused while the capsule is unsealed.
- `Release(t)` is refused while `t < deadline`.
- once `Released`, the capsule never returns to `Waiting` or `Unsealed`;
- a repeated `Release` is idempotent and preserves the original
  `released_at`, even if the later observation is earlier;
- re-sealing with the same deadline is idempotent;
- re-sealing with a different deadline is refused.

This design deliberately avoids request identifiers and receipt history. The
operations themselves are shaped so that safe retries do not need a separate
replay mechanism.

## What the timestamp means

The pure core treats timestamps only as ordered `int64` values.

It does not obtain time by itself and it does not claim that a supplied
observation corresponds to correct real-world time. A future runtime adapter is
expected to obtain the observation from its own clock source rather than accept
an authoritative `now` value from an HTTP client.

## Not established yet

This milestone does not establish:

- correctness, monotonicity, or trustworthiness of a wall clock;
- behavior across process, guest, or host restart;
- persistence or crash atomicity;
- correspondence with a TLA+ model;
- MirageOS or Solo5 execution;
- networking, TLS, authentication, or authorization;
- secrecy of any payload;
- distributed or multi-replica time semantics.

Those are separate milestones. They should be added only when concrete evidence
exists for each stronger claim.
