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

val step : state -> command -> outcome
