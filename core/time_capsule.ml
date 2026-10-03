type timestamp = int64

type state =
  | Unsealed
  | Waiting of { deadline : timestamp }
  | Released of {
      deadline : timestamp;
      released_at : timestamp;
    }

type command =
  | Seal of timestamp
  | Release of timestamp

type refusal =
  | Not_sealed
  | Too_early of {
      deadline : timestamp;
      observed_at : timestamp;
    }
  | Deadline_conflict of {
      existing_deadline : timestamp;
      requested_deadline : timestamp;
    }

type outcome =
  | Applied of state
  | Unchanged of state
  | Refused of refusal

let seal state requested_deadline =
  match state with
  | Unsealed -> Applied (Waiting { deadline = requested_deadline })
  | Waiting { deadline = existing_deadline } ->
      if Int64.equal existing_deadline requested_deadline then Unchanged state
      else
        Refused
          (Deadline_conflict { existing_deadline; requested_deadline })
  | Released { deadline = existing_deadline; _ } ->
      if Int64.equal existing_deadline requested_deadline then Unchanged state
      else
        Refused
          (Deadline_conflict { existing_deadline; requested_deadline })

let release state observed_at =
  match state with
  | Unsealed -> Refused Not_sealed
  | Waiting { deadline } ->
      if Int64.compare observed_at deadline < 0 then
        Refused (Too_early { deadline; observed_at })
      else Applied (Released { deadline; released_at = observed_at })
  | Released _ -> Unchanged state

let step state = function
  | Seal deadline -> seal state deadline
  | Release observed_at -> release state observed_at
