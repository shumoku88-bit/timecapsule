--------------------------- MODULE TimeCapsule ---------------------------
EXTENDS Integers

CONSTANTS Unsealed, Waiting, Released

VARIABLES
  phase,
  deadline,
  releasedAt

vars == <<phase, deadline, releasedAt>>

Phases == {Unsealed, Waiting, Released}
Deadlines == {1, 2}
Observations == {0, 1, 2, 3}
NoTime == -1

Init ==
  /\ phase = Unsealed
  /\ deadline = NoTime
  /\ releasedAt = NoTime

Seal ==
  \E d \in Deadlines:
    /\ phase = Unsealed
    /\ phase' = Waiting
    /\ deadline' = d
    /\ UNCHANGED releasedAt

Release ==
  \E t \in Observations:
    /\ phase = Waiting
    /\ t >= deadline
    /\ phase' = Released
    /\ releasedAt' = t
    /\ UNCHANGED deadline

Next ==
  Seal \/ Release

Spec ==
  Init /\ [][Next]_vars

TypeOK ==
  /\ phase \in Phases
  /\ deadline \in Deadlines \cup {NoTime}
  /\ releasedAt \in Observations \cup {NoTime}
  /\ (phase = Unsealed) =>
       /\ deadline = NoTime
       /\ releasedAt = NoTime
  /\ (phase = Waiting) =>
       /\ deadline \in Deadlines
       /\ releasedAt = NoTime
  /\ (phase = Released) =>
       /\ deadline \in Deadlines
       /\ releasedAt \in Observations

ReleasedTimestampValid ==
  phase # Released
    \/ /\ releasedAt >= deadline
       /\ releasedAt \in Observations

ReleasedPermanent ==
  []((phase = Released) => [](phase = Released))

=============================================================================
