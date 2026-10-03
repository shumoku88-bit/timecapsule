# MirageOS clock boundary

This adapter exists to establish one narrow runtime property:

> a client may choose a deadline, but it may not supply the authoritative
> `now` used by `Release`.

The HTTP surface is deliberately small:

- `GET /state`
- `POST /seal?deadline=<unix-seconds>`
- `POST /release`

`POST /release` obtains its observation from `Mirage_ptime.now ()` inside the
unikernel, converts it to integer Unix seconds, and passes that value into the
pure core.

The adapter is intentionally volatile in this milestone. Restarting it resets
the capsule to `Unsealed`.

No claim is made here that the wall clock is correct, monotonic, authenticated,
or resistant to a malicious host or hypervisor.
