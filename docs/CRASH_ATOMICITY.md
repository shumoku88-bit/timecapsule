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

The bounded TLA+ crash-recovery model checks that:

- visible state never advances ahead of durable state;
- idle state agrees with durable state;
- a prepared state is not yet visible;
- a committed state is already durable;
- a visible `Released` state implies durable `Released`;
- once durable state reaches `Released`, it never regresses.

The negative control deliberately publishes `Released` before committing it.
A crash in that gap recovers the old durable `Waiting` state, and TLC is
required to expose that rollback.

## Runtime crash injection

The MirageOS Unix adapter also exposes a test-only `--failure-point` argument.
Its default is `none`. Two values pause an `Applied` mutation at concrete
application/KV boundaries:

- `before-commit`: immediately before `Store.set /capsule`;
- `after-commit-before-publish`: after `Store.set` returns `Ok ()`, before
  updating the in-memory state or sending the HTTP response.

The runtime harness first persists `Waiting(0)`, then exercises `Release`.

For `before-commit`, it kills the Unix unikernel while paused and reboots on
the same backing image. Recovery must still be `Waiting(0)`. Retrying
`Release` then succeeds normally.

For `after-commit-before-publish`, it kills the unikernel after the durable
write returned successfully but before publication. Recovery must be
`Released(0, released_at)`, and retrying `Release` must preserve the same
latched `released_at`.

This runtime evidence connects the abstract ordering model to the concrete
TimeCapsule application/KV commit boundary.

## Claim boundary

The runtime test establishes process-kill/restart behavior for the tested
MirageOS Unix + Chamelon path at these two injected boundaries.

It does not establish:

- host power-loss durability;
- loss of host page cache;
- storage-controller cache loss;
- arbitrary torn host writes;
- one-for-one correspondence between Chamelon internals and TLA+ steps;
- Solo5 hvt crash-boundary behavior;
- correctness or trustworthiness of the wall clock.
