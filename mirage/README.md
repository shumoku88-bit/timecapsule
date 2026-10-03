# MirageOS runtime boundary

The MirageOS adapter connects the pure TimeCapsule state machine to two runtime
resources:

- a wall-clock observation from `Mirage_ptime.now ()`;
- a Chamelon key/value store backed by the `capsule` block image.

The HTTP surface remains deliberately small:

- `GET /state`
- `POST /seal?deadline=<unix-seconds>`
- `POST /release`

A client may choose a deadline, but it may not supply the authoritative `now`
used by `Release`.

State-changing operations are persisted before their new state is published to
the running service. The adapter stores exactly one snapshot at `/capsule`.

See `docs/CLOCK_BOUNDARY.md` and `docs/PERSISTENCE.md` for the exact claim
boundaries.

No claim is made that the wall clock is correct, monotonic, authenticated, or
resistant to a malicious host or hypervisor. The current persistence evidence
covers tested Unix process restart with the same backing image, not host
power-loss durability.
