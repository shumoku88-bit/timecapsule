# TimeCapsule

TimeCapsule is an experiment in building a tiny, inspectable, single-purpose
computer around one property: a time condition can become a latched fact.

The first machine is deliberately small:

```text
Unsealed --Seal(deadline)--> Waiting(deadline)
Waiting(deadline) --Release(now >= deadline)--> Released(deadline, released_at)
```

A release that happens once never becomes unreleased, even if a later clock
observation moves backwards.

## First milestone

The initial milestone contains only pure OCaml semantics and tests.

Its design choices are intentionally different from StateCapsule:

- no request identifiers,
- no receipt history,
- repeated commands are idempotent where that is safe,
- the clock observation is explicit input to the pure core,
- the eventual runtime adapter, not the client, will own clock observation.

Persistence, MirageOS, Solo5, TLA+, crash recovery, and concrete clock binding
are deliberately deferred to later milestones.

See `docs/CLAIM_BOUNDARY.md` for the exact current claim boundary.
