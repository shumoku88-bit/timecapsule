module Capsule = Timecapsule_core.Time_capsule
module Snapshot = Timecapsule_core.Snapshot

let check_state label expected actual =
  Alcotest.(check bool) label true (expected = actual)

let expect_round_trip state =
  match Snapshot.decode (Snapshot.encode state) with
  | Ok restored -> check_state "round trip" state restored
  | Error error -> Alcotest.failf "snapshot restore failed: %s" error

let test_round_trip_unsealed () =
  expect_round_trip Capsule.Unsealed

let test_round_trip_waiting () =
  expect_round_trip (Capsule.Waiting { deadline = 42L })

let test_round_trip_released () =
  expect_round_trip
    (Capsule.Released { deadline = 42L; released_at = 50L })

let test_corruption_is_rejected () =
  let payload = Snapshot.encode (Capsule.Waiting { deadline = 42L }) in
  let corrupted = payload ^ "x" in
  match Snapshot.decode corrupted with
  | Error _ -> ()
  | Ok _ -> Alcotest.fail "corrupt snapshot was accepted"

let payload_with_checksum body =
  body ^ "\nchecksum=" ^ Digest.to_hex (Digest.string body)

let test_semantically_invalid_release_is_rejected () =
  let payload =
    payload_with_checksum "TC1\nreleased|50|42"
  in
  match Snapshot.decode payload with
  | Error "released_at precedes deadline" -> ()
  | Error error ->
      Alcotest.failf "unexpected validation error: %s" error
  | Ok _ ->
      Alcotest.fail "semantically invalid released snapshot was accepted"

let test_unknown_version_is_rejected () =
  let payload =
    payload_with_checksum "TC2\nunsealed"
  in
  match Snapshot.decode payload with
  | Error "unsupported snapshot format" -> ()
  | Error error ->
      Alcotest.failf "unexpected validation error: %s" error
  | Ok _ ->
      Alcotest.fail "unknown snapshot version was accepted"

let () =
  Alcotest.run "TimeCapsule snapshot"
    [
      ( "codec",
        [
          Alcotest.test_case "unsealed round trip" `Quick
            test_round_trip_unsealed;
          Alcotest.test_case "waiting round trip" `Quick
            test_round_trip_waiting;
          Alcotest.test_case "released round trip" `Quick
            test_round_trip_released;
          Alcotest.test_case "corruption rejected" `Quick
            test_corruption_is_rejected;
          Alcotest.test_case "invalid released chronology rejected" `Quick
            test_semantically_invalid_release_is_rejected;
          Alcotest.test_case "unknown version rejected" `Quick
            test_unknown_version_is_rejected;
        ] );
    ]
