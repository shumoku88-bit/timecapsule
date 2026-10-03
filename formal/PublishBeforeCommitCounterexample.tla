---------------- MODULE PublishBeforeCommitCounterexample ----------------
CONSTANTS Waiting, Released

States == {Waiting, Released}
Phases == {"idle", "prepared", "published", "crashed", "recovered"}

VARIABLES
  visibleState,
  durableState,
  phase,
  releaseWasPublished

vars == <<visibleState, durableState, phase, releaseWasPublished>>

Init ==
  /\ visibleState = Waiting
  /\ durableState = Waiting
  /\ phase = "idle"
  /\ releaseWasPublished = FALSE

PrepareRelease ==
  /\ phase = "idle"
  /\ phase' = "prepared"
  /\ UNCHANGED <<visibleState, durableState, releaseWasPublished>>

PublishBeforeCommit ==
  /\ phase = "prepared"
  /\ visibleState' = Released
  /\ releaseWasPublished' = TRUE
  /\ phase' = "published"
  /\ UNCHANGED durableState

Commit ==
  /\ phase = "published"
  /\ durableState' = Released
  /\ phase' = "idle"
  /\ UNCHANGED <<visibleState, releaseWasPublished>>

CrashAfterPublish ==
  /\ phase = "published"
  /\ phase' = "crashed"
  /\ UNCHANGED <<visibleState, durableState, releaseWasPublished>>

Recover ==
  /\ phase = "crashed"
  /\ visibleState' = durableState
  /\ phase' = "recovered"
  /\ UNCHANGED <<durableState, releaseWasPublished>>

Next ==
  PrepareRelease
  \/ PublishBeforeCommit
  \/ Commit
  \/ CrashAfterPublish
  \/ Recover

Spec ==
  Init /\ [][Next]_vars

TypeOK ==
  /\ visibleState \in States
  /\ durableState \in States
  /\ phase \in Phases
  /\ releaseWasPublished \in BOOLEAN

PublishedReleaseCannotRelock ==
  ~releaseWasPublished \/ visibleState = Released

=============================================================================
