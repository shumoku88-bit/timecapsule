# Persistence crash atomicity model

TimeCapsule has a smaller crash problem than StateCapsule.

There is only one authoritative durable value: the capsule state. There is no
separate request receipt that must be committed atomically with it.

The model therefore focuses on one ordering rule:

```text
prepare next state
      |
      v
commit durable snapshot
      |
      v
publish visible state
```

A crash may occur before or after the durable commit.

## Crash before commit

If the process crashes while the next state is only prepared, recovery restores
the previous durable state. No newer state was published.

## Crash after commit, before publish

If the durable snapshot has been committed but the new state has not yet been
published, recovery restores the committed state. The client may have missed
the response, but a retry is safe because TimeCapsule operations are
idempotent.

## Checked properties

The bounded TLA+ model checks:

- visible state never advances ahead of durable state;
- idle state agrees with durable state;
- a prepared state is not yet visible;
- a committed state is already durable;
- a visible `Released` state implies durable `Released`;
- once durable state reaches `Released`, it never regresses.

The model abstracts timestamps away because the clock-ordering properties are
already checked by `TimeCapsule.tla`. This model is specifically about
publication and persistence ordering.

## Negative control

`PublishBeforeCommitCounterexample.tla` deliberately reverses the important
ordering:

```text
prepare release
      |
      v
publish Released
      |
      v
commit durable Released
```

It then crashes after publication but before commit. Recovery reads the old
durable `Waiting` state, so an externally visible `Released` fact becomes
`Waiting` again.

CI requires TLC to find that counterexample.

## Claim boundary

This is a bounded abstract model. It does not establish that Chamelon,
MirageOS, Solo5, the host kernel, or physical storage actually implements the
abstract commit boundary atomically. Runtime crash injection is a separate
milestone.
