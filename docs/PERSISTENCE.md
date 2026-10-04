# Persistence boundary

TimeCapsule persists exactly one authoritative value: its current state.

The MirageOS adapter stores one versioned snapshot at the Chamelon key
`/capsule`.

```text
evaluate command in memory
        |
        v
Applied(next_state)
        |
        v
encode complete TC1 snapshot
        |
        v
Store.set /capsule
        |
        +-- error --> do not publish next_state; block further service use
        |
        v
      Ok ()
        |
        v
publish next_state and HTTP success
```

`Unchanged` and `Refused` outcomes do not write because they do not change
the authoritative state.

Unlike StateCapsule, TimeCapsule has no request-id or receipt history. Its
commands are shaped to make safe retries idempotent.

## Snapshot validation

The `TC1` snapshot contains:

- one state value;
- all timestamps required by that state;
- an integrity checksum.

Restore rejects unknown versions, malformed state shapes, malformed timestamps,
checksum mismatches, and a released state whose `released_at` precedes its
`deadline`.

The checksum detects accidental corruption. It is not authentication.

## Evidence

The MirageOS Unix persistence test establishes that, using the same Chamelon
backing image:

- `Waiting(deadline)` survives process restart;
- `Released(deadline, released_at)` survives process restart;
- a repeated release after restart preserves the original `released_at`;
- a corrupt persisted snapshot causes fail-closed startup.

The separate crash-boundary test injects process kills immediately before
`Store.set` and immediately after `Store.set` returns `Ok ()` but before
publication. See `CRASH_ATOMICITY.md`.

## Not established

The current evidence does not establish host power-loss durability, arbitrary
torn-write behavior, Solo5 hvt crash-boundary behavior, trustworthy wall-clock
time, TLS, authentication, or authorization.
