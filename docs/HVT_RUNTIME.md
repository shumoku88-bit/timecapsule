# Solo5 hvt runtime evidence

This milestone moves the TimeCapsule persistence boundary from the MirageOS
Unix target into a Solo5 hvt guest.

The hvt harness uses:

- a dedicated TAP/bridge network;
- a Chamelon backing image attached as the `capsule` block device;
- the same TimeCapsule HTTP adapter and test-only failure points used by the
  Unix crash-boundary test.

## Exercised behavior

The harness first establishes ordinary reboot continuity:

```text
Waiting(0)
  -> Release
  -> Released(0, released_at)
  -> kill guest
  -> reboot same image
  -> Released(0, same released_at)
```

It then injects two crashes during `Release`.

### Before commit

The guest pauses immediately before `Store.set /capsule`. The harness kills
the guest and reboots from the same image.

Recovery must still be `Waiting(0)`. Retrying `Release` may then create the
durable `Released` fact.

### After commit, before publish

The guest pauses after `Store.set` returns `Ok ()` but before the in-memory
state changes or the HTTP response is sent. The harness kills the guest and
reboots from the same image.

Recovery must be `Released(0, released_at)`. Retrying `Release` must return
the same state and preserve the original `released_at`.

## Claim boundary

This evidence covers the tested Solo5 hvt guest/tender/backing-image restart
path and the two injected application/KV boundaries.

It does not establish host power-loss durability, host kernel failure
durability, volatile page-cache loss, storage-controller cache behavior,
arbitrary torn host writes, secure wall-clock time, TLS, authentication, or
authorization.
