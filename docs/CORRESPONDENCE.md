# OCaml / TLA+ correspondence

This milestone compares the successful bounded transition relation exposed by
the pure OCaml core with the state graph actually explored by TLC.

The bounded domains are the same ones used by the first TLA+ model:

- deadlines: `1`, `2`
- clock observations: `0`, `1`, `2`, `3`

For those domains, the expected state-changing transitions are:

```text
unsealed   seal:1      waiting:1
unsealed   seal:2      waiting:2
waiting:1  release:1   released:1:1
waiting:1  release:2   released:1:2
waiting:1  release:3   released:1:3
waiting:2  release:2   released:2:2
waiting:2  release:3   released:2:3
```

The check is intentionally mechanical:

1. TLC dumps the explored state graph with action labels.
2. `normalize_tlc_dot.py` derives the concrete deadline or release observation
   from the destination state and emits a normalized transition table.
3. `dump_ocaml_transitions.ml` independently enumerates the same bounded input
   space and emits only `Applied` transitions.
4. CI sorts both tables and requires byte-for-byte equality.

Idempotent retries are not state-changing transitions. In the TLA+ model they
are represented by stuttering rather than explicit `Seal` or `Release`
steps, so the correspondence claim here is only about successful state changes.

This does not prove correspondence for arbitrary `int64` timestamps. It does
not cover refusal reasons, persistence, crash recovery, networking, or any
concrete clock source.
