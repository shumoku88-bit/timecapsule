--------------------------- MODULE CrashRecovery ---------------------------
EXTENDS Naturals

CONSTANTS
  Unsealed,
  Waiting,
  Released

States == {Unsealed, Waiting, Released}

StateRank(s) ==
  CASE s = Unsealed -> 0
    [] s = Waiting -> 1
    [] s = Released -> 2

Phases ==
  {"idle", "prepared", "committed", "crashed"}

VARIABLES
  visibleState,
  durableState,
  pendingState,
  phase

vars == <<visibleState, durableState, pendingState, phase>>

Init ==
  /\ visibleState = Unsealed
  /\ durableState = Unsealed
  /\ pendingState = Unsealed
  /\ phase = "idle"

PrepareSeal ==
  /\ phase = "idle"
  /\ visibleState = Unsealed
  /\ pendingState' = Waiting
  /\ phase' = "prepared"
  /\ UNCHANGED <<visibleState, durableState>>

PrepareRelease ==
  /\ phase = "idle"
  /\ visibleState = Waiting
  /\ pendingState' = Released
  /\ phase' = "prepared"
  /\ UNCHANGED <<visibleState, durableState>>

Commit ==
  /\ phase = "prepared"
  /\ durableState' = pendingState
  /\ phase' = "committed"
  /\ UNCHANGED <<visibleState, pendingState>>

Publish ==
  /\ phase = "committed"
  /\ visibleState' = durableState
  /\ pendingState' = durableState
  /\ phase' = "idle"
  /\ UNCHANGED durableState

Crash ==
  /\ phase # "crashed"
  /\ phase' = "crashed"
  /\ UNCHANGED <<visibleState, durableState, pendingState>>

Recover ==
  /\ phase = "crashed"
  /\ visibleState' = durableState
  /\ pendingState' = durableState
  /\ phase' = "idle"
  /\ UNCHANGED durableState

Next ==
  PrepareSeal
  \/ PrepareRelease
  \/ Commit
  \/ Publish
  \/ Crash
  \/ Recover

Spec ==
  Init /\ [][Next]_vars

TypeOK ==
  /\ visibleState \in States
  /\ durableState \in States
  /\ pendingState \in States
  /\ phase \in Phases

VisibleNeverAheadOfDurability ==
  StateRank(visibleState) <= StateRank(durableState)

IdleMatchesDurable ==
  phase # "idle" \/ visibleState = durableState

PreparedDoesNotPublish ==
  phase # "prepared" \/ visibleState = durableState

CommittedStateIsDurable ==
  phase # "committed" \/ durableState = pendingState

DurableNeverBehindVisibleRelease ==
  visibleState # Released \/ durableState = Released

ReleasedDurablePermanent ==
  [](durableState = Released => [](durableState = Released))

=============================================================================
