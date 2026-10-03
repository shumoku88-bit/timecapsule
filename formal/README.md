# Formal model

The first bounded TimeCapsule model focuses on the property that makes this
capsule distinct from StateCapsule: once a deadline crossing has been accepted
as a release fact, later clock observations cannot make the capsule waiting
again.

## Positive model

`TimeCapsule.tla` explores a finite time domain with two possible deadlines
and four possible clock observations.

The successful transition relation is:

```text
Unsealed --Seal(d)--> Waiting(d)
Waiting(d) --Release(t), t >= d--> Released(d, t)
```

TLC checks:

- `TypeOK`: every reachable state has the expected shape;
- `ReleasedTimestampValid`: every released state records a release
  observation at or after its deadline;
- `ReleasedPermanent`: once the phase is `Released`, every future state is
  also `Released`.

The model deliberately represents only state-changing operations. Idempotent
retries in the OCaml core correspond to stuttering and do not need additional
state transitions here.

This is a bounded model. It does not prove arbitrary `int64` arithmetic,
clock correctness, persistence, crash recovery, or correspondence with the
OCaml implementation.

## Clock rollback negative control

`ClockRollbackCounterexample.tla` models a tempting but incorrect design:
derive the visible phase directly from the current wall-clock observation.

```text
visible = if now >= deadline then Released else Waiting
```

The model records that the deadline has once been crossed and then permits the
clock to roll backwards. TLC must find a trace where the capsule becomes
visibly waiting again.

CI treats that counterexample as a required result. If TLC stops finding it,
the negative control fails.

The point is narrow: a release fact must be latched into state rather than
re-derived from a wall clock that may later move backwards.
