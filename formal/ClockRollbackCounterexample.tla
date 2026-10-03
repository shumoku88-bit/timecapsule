-------------------- MODULE ClockRollbackCounterexample --------------------
EXTENDS Integers

CONSTANTS Waiting, Released

VARIABLES
  now,
  crossed

vars == <<now, crossed>>

Times == {0, 1, 2}
Deadline == 1

VisiblePhase ==
  IF now >= Deadline THEN Released ELSE Waiting

Init ==
  /\ now = 0
  /\ crossed = FALSE

Advance ==
  /\ now < 2
  /\ now' = now + 1
  /\ crossed' = (crossed \/ now' >= Deadline)

Rollback ==
  /\ now >= Deadline
  /\ now' = 0
  /\ crossed' = crossed

Next ==
  Advance \/ Rollback

Spec ==
  Init /\ [][Next]_vars

TypeOK ==
  /\ now \in Times
  /\ crossed \in BOOLEAN

NoRelockAfterObservedRelease ==
  ~crossed \/ VisiblePhase = Released

=============================================================================
