# Runtime clock boundary

The pure TimeCapsule core accepts `Release(observed_at)` because time is an
input to the state machine.

That does not mean an HTTP client should be allowed to choose that input.

The MirageOS adapter therefore has a deliberately asymmetric API:

- the client may provide a deadline when sealing;
- the client cannot provide `now` when releasing;
- the unikernel reads `Mirage_ptime.now ()` when it handles
  `POST /release`;
- that runtime observation is the value passed to the pure core.

The Unix smoke test exercises the clock boundary with both a far-future
deadline and a deadline at zero. It also checks that
`/release?now=0` is not an accepted release endpoint.

Solo5 hvt runtime tests exercise the same adapter in a freestanding guest.

## What this establishes

For the tested MirageOS Unix and Solo5 hvt runtime paths, release decisions are
driven by a clock observation obtained inside the unikernel rather than an
authoritative timestamp supplied by the HTTP client.

Persistence of the resulting state is documented separately in
`PERSISTENCE.md`.

## What this does not establish

This does not establish:

- correctness of real-world wall time;
- monotonicity of the wall clock;
- resistance to host or hypervisor clock manipulation;
- TLS, authentication, or authorization.
