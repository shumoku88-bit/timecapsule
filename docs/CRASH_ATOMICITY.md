# Persistence crash atomicity

TimeCapsule has a smaller crash problem than StateCapsule.

There is only one authoritative durable value: the capsule state. There is no
separate request receipt that must be committed atomically with it.

The required ordering is:

```text
prepare next state
      |
      v
commit durable snapshot
      |
      v
publish visible state
```

## Abstract model

The bounded TLA+ crash-recovery model checks that visible state never advances
ahead of durable state, recovery restores durable state, and durable
`Released` never regresses.

The negative control deliberately publishes `Released` before committing it.
A crash in that gap recovers the old durable `Waiting` state, and TLC is
required to expose that rollback.

## Runtime crash injection

The MirageOS adapter exposes a test-only `--failure-point` argument whose
default is `none`:

- `before-commit`: immediately before `Store.set /capsule`;
- `after-commit-before-publish`: after `Store.set` returns `Ok ()`, before
  updating in-memory state or sending the HTTP response.

Both the Unix harness and the Solo5 hvt harness persist `Waiting(0)`, trigger
`Release`, kill the runtime at each boundary, and restart from the same
backing image.

The required recovery behavior is:

- before commit -> `Waiting(0)`;
- after commit but before publish -> `Released(0, released_at)`;
- retry after recovered `Released` preserves the same `released_at`.

See `HVT_RUNTIME.md` for the hvt-specific evidence boundary.

## Claim boundary

The runtime tests exercise concrete application/KV boundaries. They do not
establish host power-loss durability, arbitrary torn host writes, or
one-for-one correspondence between Chamelon internals and TLA+ steps.
