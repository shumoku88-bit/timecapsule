# Claim boundary

TimeCapsule establishes a narrow property:

> once a deadline crossing is accepted as a release fact, that fact is latched
> into durable state and is not re-derived from later wall-clock observations.

## Pure semantics

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

The pure contract includes:

- `Release` is refused while unsealed;
- `Release(t)` is refused while `t < deadline`;
- once `Released`, the capsule never returns to `Waiting` or `Unsealed`;
- repeated `Release` is idempotent and preserves the original
  `released_at`, including after a later lower clock observation;
- re-sealing with the same deadline is idempotent;
- re-sealing with a different deadline is refused.

The design deliberately avoids request identifiers and receipt history.

## Formal evidence

The repository contains:

- a bounded TLA+ model of the TimeCapsule transition relation;
- a required negative control showing that deriving visible state from current
  wall time can relock after clock rollback;
- a bounded correspondence check between the TLA+ state graph and successful
  OCaml transitions;
- a bounded crash-recovery model requiring durable commit before publication;
- a required negative control showing that publish-before-commit can expose
  `Released` and then recover to `Waiting`.

These are bounded model-checking claims, not proofs over all `int64` values or
all possible storage implementations.

## Runtime clock boundary

The MirageOS adapter owns the clock observation used for `Release`.

A client may choose the deadline when sealing, but `POST /release` does not
accept an authoritative `now` parameter. The adapter obtains the observation
from `Mirage_ptime.now ()`.

This establishes who supplies the observation in the tested runtime. It does
not establish that the observation equals correct real-world time.

## Persistence and recovery evidence

The tested runtime persists one versioned snapshot containing the current
TimeCapsule state.

Evidence includes:

- `Waiting` and `Released` surviving MirageOS Unix process restart;
- the original `released_at` surviving restart and repeated release;
- fail-closed startup on corrupt persisted state;
- process-kill injection immediately before `Store.set /capsule`;
- process-kill injection after `Store.set` returns `Ok ()` but before
  in-memory/HTTP publication;
- the same reboot and crash-boundary behavior exercised under Solo5 hvt using
  the same backing image across guest restarts.

At the injected pre-commit boundary, recovery remains at the previous durable
state. At the injected post-commit/pre-publish boundary, recovery observes the
new durable state.

## Not established

TimeCapsule does not establish:

- correctness, monotonicity, authenticity, or adversarial robustness of
  real-world wall time;
- host power-loss durability;
- durability under host kernel failure;
- durability after loss of volatile host page cache or storage-controller
  cache;
- arbitrary torn host writes;
- one-for-one correspondence between Chamelon internals and TLA+ steps;
- TLS, authentication, or authorization;
- secrecy of stored or transmitted payloads;
- distributed or multi-replica time semantics.

Stronger claims should be added only when concrete evidence exists for them.
