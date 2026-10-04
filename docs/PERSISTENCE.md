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
commands are shaped so safe retries do not need a separate replay ledger.

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

Using the same Chamelon backing image, the repository tests establish:

- `Waiting(deadline)` survives MirageOS Unix process restart;
- `Released(deadline, released_at)` survives restart;
- repeated release preserves the original `released_at`;
- corrupt persisted state causes fail-closed startup;
- a kill immediately before `Store.set` recovers the previous durable state;
- a kill after `Store.set` returns `Ok ()` but before publication recovers
  the newly durable state;
- Solo5 hvt guest restart exercises the same reboot and crash-boundary behavior.

See `CRASH_ATOMICITY.md` and `HVT_RUNTIME.md` for the exact tested
boundaries.

## Not established

The current evidence does not establish host power-loss durability, host kernel
failure durability, arbitrary torn-write behavior, volatile cache-loss
durability, trustworthy wall-clock time, TLS, authentication, or authorization.
