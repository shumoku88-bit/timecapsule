open Timecapsule_core.Time_capsule

let deadlines = [ 1L; 2L ]
let observations = [ 0L; 1L; 2L; 3L ]

let state_to_string = function
  | Unsealed -> "unsealed"
  | Waiting { deadline } ->
      Printf.sprintf "waiting:%Ld" deadline
  | Released { deadline; released_at } ->
      Printf.sprintf "released:%Ld:%Ld" deadline released_at

let command_to_string = function
  | Seal deadline -> Printf.sprintf "seal:%Ld" deadline
  | Release observed_at -> Printf.sprintf "release:%Ld" observed_at

let valid_released_states =
  List.concat_map
    (fun deadline ->
      List.filter_map
        (fun released_at ->
          if Int64.compare released_at deadline >= 0 then
            Some (Released { deadline; released_at })
          else None)
        observations)
    deadlines

let states =
  Unsealed
  :: (List.map (fun deadline -> Waiting { deadline }) deadlines
     @ valid_released_states)

let commands =
  List.map (fun deadline -> Seal deadline) deadlines
  @ List.map (fun observed_at -> Release observed_at) observations

let () =
  List.iter
    (fun before ->
      List.iter
        (fun command ->
          match step before command with
          | Applied after ->
              Printf.printf
                "%s\t%s\t%s\n"
                (state_to_string before)
                (command_to_string command)
                (state_to_string after)
          | Unchanged _
          | Refused _ -> ())
        commands)
    states
