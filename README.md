# TimeCapsule

TimeCapsule is an experiment in building a tiny, inspectable, single-purpose
computer around one property: a time condition can become a latched fact.

The machine is deliberately small:

```text
Unsealed --Seal(deadline)--> Waiting(deadline)
Waiting(deadline) --Release(now >= deadline)--> Released(deadline, released_at)
```

A release that happens once never becomes unreleased, even if a later clock
observation moves backwards.

## Current evidence

TimeCapsule now has a complete narrow evidence chain around that property:

- pure OCaml state-machine semantics and tests;
- a bounded TLA+ model;
- a required clock-rollback counterexample for the naive wall-clock-derived design;
- bounded OCaml/TLA+ successful-transition correspondence;
- a MirageOS runtime boundary where the client cannot supply authoritative
  `now`;
- a versioned Chamelon snapshot with checksum and semantic validation;
- fail-closed startup on invalid persisted state;
- a bounded crash-recovery model requiring durable commit before publication;
- a required publish-before-commit counterexample;
- Unix process-kill crash injection immediately before and immediately after
  the concrete `Store.set` boundary;
- a Solo5 hvt artifact and runtime test covering reboot continuity and the same
  two crash boundaries.

The design intentionally differs from StateCapsule:

- no request identifiers;
- no receipt history;
- repeated commands are idempotent where that is safe;
- the pure core treats clock observations as explicit inputs;
- the runtime adapter, not the HTTP client, obtains the authoritative clock
  observation used by `Release`;
- persistence contains exactly one authoritative state snapshot.

## HTTP surface

The current MirageOS adapter exposes:

```text
GET  /state
POST /seal?deadline=<unix-seconds>
POST /release
```

`POST /release` does not accept a client-supplied `now` value.

## Claim boundary

The evidence is intentionally narrow. It does not claim correct or secure
real-world time, host power-loss durability, arbitrary torn-write tolerance,
TLS, authentication, authorization, payload secrecy, or distributed
multi-replica semantics.

See `docs/CLAIM_BOUNDARY.md` for the exact current claim boundary and the
other files under `docs/` for the evidence behind each layer.
