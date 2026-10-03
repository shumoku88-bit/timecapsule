# Runtime clock boundary

The pure TimeCapsule core accepts `Release(observed_at)` because time is an
input to the state machine.

That does not mean an HTTP client should be allowed to choose that input.

This milestone therefore introduces a MirageOS adapter with a deliberately
asymmetric API:

- the client may provide a deadline when sealing;
- the client cannot provide `now` when releasing;
- the unikernel reads `Mirage_ptime.now ()` exactly when it handles
  `POST /release`;
- that runtime observation is the value passed to the pure core.

The Unix smoke test exercises three boundaries:

1. releasing while unsealed is refused;
2. a deadline in the year 2100 is still too early with the runtime clock;
3. deadline `0` releases successfully and records a positive runtime
   observation.

It also checks that `/release?now=0` is not an accepted release endpoint.

## What this establishes

For the tested MirageOS Unix runtime, release decisions are driven by a clock
observation obtained inside the unikernel rather than an authoritative
timestamp supplied by the HTTP client.

## What this does not establish

This does not establish:

- correctness of real-world wall time;
- monotonicity of the wall clock;
- resistance to host or hypervisor clock manipulation;
- persistence across restart;
- crash atomicity;
- Solo5 hvt execution;
- TLS, authentication, or authorization.

Those remain separate milestones.
