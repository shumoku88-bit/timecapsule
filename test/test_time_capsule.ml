open Timecapsule_core

module Time_capsule = Time_capsule

open Time_capsule

let check_i64 label expected actual =
  Alcotest.(check string) label (Int64.to_string expected) (Int64.to_string actual)

let check_state_equal label expected actual =
  Alcotest.(check bool) label true (expected = actual)

let test_seal_fresh () =
  match step Unsealed (Seal 10L) with
  | Applied (Waiting { deadline }) -> check_i64 "deadline" 10L deadline
  | _ -> Alcotest.fail "fresh seal should enter Waiting"

let test_same_seal_is_idempotent () =
  let state = Waiting { deadline = 10L } in
  match step state (Seal 10L) with
  | Unchanged state' -> check_state_equal "unchanged" state state'
  | _ -> Alcotest.fail "same deadline should be unchanged"

let test_conflicting_seal_is_refused () =
  let state = Waiting { deadline = 10L } in
  match step state (Seal 11L) with
  | Refused (Deadline_conflict { existing_deadline; requested_deadline }) ->
      check_i64 "existing" 10L existing_deadline;
      check_i64 "requested" 11L requested_deadline
  | _ -> Alcotest.fail "different deadline should conflict"

let test_release_before_seal_is_refused () =
  match step Unsealed (Release 10L) with
  | Refused Not_sealed -> ()
  | _ -> Alcotest.fail "release before seal should be refused"

let test_early_release_is_refused () =
  let state = Waiting { deadline = 10L } in
  match step state (Release 9L) with
  | Refused (Too_early { deadline; observed_at }) ->
      check_i64 "deadline" 10L deadline;
      check_i64 "observed" 9L observed_at
  | _ -> Alcotest.fail "release before deadline should be refused"

let test_release_at_deadline () =
  let state = Waiting { deadline = 10L } in
  match step state (Release 10L) with
  | Applied (Released { deadline; released_at }) ->
      check_i64 "deadline" 10L deadline;
      check_i64 "released_at" 10L released_at
  | _ -> Alcotest.fail "release at deadline should apply"

let test_release_after_deadline () =
  let state = Waiting { deadline = 10L } in
  match step state (Release 12L) with
  | Applied (Released { deadline; released_at }) ->
      check_i64 "deadline" 10L deadline;
      check_i64 "released_at" 12L released_at
  | _ -> Alcotest.fail "release after deadline should apply"

let test_repeated_release_latches_original_fact () =
  let state = Released { deadline = 10L; released_at = 12L } in
  match step state (Release 3L) with
  | Unchanged (Released { deadline; released_at }) ->
      check_i64 "deadline" 10L deadline;
      check_i64 "released_at remains latched" 12L released_at
  | _ -> Alcotest.fail "released state should remain released after clock rollback"

let test_same_seal_after_release_is_idempotent () =
  let state = Released { deadline = 10L; released_at = 12L } in
  match step state (Seal 10L) with
  | Unchanged state' -> check_state_equal "unchanged" state state'
  | _ -> Alcotest.fail "same seal after release should be unchanged"

let test_conflicting_seal_after_release_is_refused () =
  let state = Released { deadline = 10L; released_at = 12L } in
  match step state (Seal 20L) with
  | Refused (Deadline_conflict { existing_deadline; requested_deadline }) ->
      check_i64 "existing" 10L existing_deadline;
      check_i64 "requested" 20L requested_deadline
  | _ -> Alcotest.fail "released capsule must reject a new deadline"

let () =
  Alcotest.run "TimeCapsule"
    [
      ( "state machine",
        [
          Alcotest.test_case "seal fresh" `Quick test_seal_fresh;
          Alcotest.test_case "same seal is idempotent" `Quick
            test_same_seal_is_idempotent;
          Alcotest.test_case "conflicting seal is refused" `Quick
            test_conflicting_seal_is_refused;
          Alcotest.test_case "release before seal is refused" `Quick
            test_release_before_seal_is_refused;
          Alcotest.test_case "early release is refused" `Quick
            test_early_release_is_refused;
          Alcotest.test_case "release at deadline" `Quick
            test_release_at_deadline;
          Alcotest.test_case "release after deadline" `Quick
            test_release_after_deadline;
          Alcotest.test_case "release remains latched across clock rollback" `Quick
            test_repeated_release_latches_original_fact;
          Alcotest.test_case "same seal after release is idempotent" `Quick
            test_same_seal_after_release_is_idempotent;
          Alcotest.test_case "conflicting seal after release is refused" `Quick
            test_conflicting_seal_after_release_is_refused;
        ] );
    ]
