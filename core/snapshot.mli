(** Durable encoding for a single TimeCapsule state.

    The format contains a version marker and an integrity checksum. The checksum
    detects accidental corruption; it is not an authentication mechanism. *)

val encode : Time_capsule.state -> string

(** [decode payload] validates the version, checksum, shape, integer fields, and
    the semantic constraint [released_at >= deadline] for released states. *)
val decode : string -> (Time_capsule.state, string) result
