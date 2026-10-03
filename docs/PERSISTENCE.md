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

Restore rejects:

- unknown versions;
- malformed state shapes;
- malformed timestamps;
- checksum mismatches;
- a released state whose `released_at` is earlier than its `deadline`.

The checksum detects accidental corruption. It is not authentication.

## Evidence in this milestone

The MirageOS Unix smoke test establishes that, using the same Chamelon backing
image:

- `Waiting(deadline)` survives process restart;
- `Released(deadline, released_at)` survives process restart;
- a repeated release after restart preserves the original `released_at`;
- a corrupt persisted snapshot causes fail-closed startup.

## Not established

This milestone does not establish:

- atomicity under a kill at each internal storage boundary;
- host power-loss durability;
- arbitrary torn-write behavior;
- Solo5 hvt restart continuity;
- correctness or trustworthiness of the wall clock;
- TLS, authentication, or authorization.

Those require separate evidence.
