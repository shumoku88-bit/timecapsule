module Capsule = Time_capsule

let state_line = function
  | Capsule.Unsealed ->
      "unsealed"
  | Capsule.Waiting { deadline } ->
      Printf.sprintf "waiting|%Ld" deadline
  | Capsule.Released { deadline; released_at } ->
      Printf.sprintf "released|%Ld|%Ld" deadline released_at

let encode state =
  let body = String.concat "\n" [ "TC1"; state_line state ] in
  let checksum = Digest.to_hex (Digest.string body) in
  body ^ "\nchecksum=" ^ checksum

let parse_int64 field value =
  match Int64.of_string_opt value with
  | Some parsed -> Ok parsed
  | None -> Error (Printf.sprintf "invalid %s timestamp %S" field value)

let parse_state = function
  | "unsealed" ->
      Ok Capsule.Unsealed
  | line ->
      match String.split_on_char '|' line with
      | [ "waiting"; deadline_text ] ->
          Result.map
            (fun deadline -> Capsule.Waiting { deadline })
            (parse_int64 "deadline" deadline_text)
      | [ "released"; deadline_text; released_at_text ] ->
          (match parse_int64 "deadline" deadline_text with
           | Error error -> Error error
           | Ok deadline ->
               (match parse_int64 "released_at" released_at_text with
                | Error error -> Error error
                | Ok released_at ->
                    if Int64.compare released_at deadline < 0 then
                      Error "released_at precedes deadline"
                    else
                      Ok (Capsule.Released { deadline; released_at })))
      | _ ->
          Error "invalid snapshot state"

let decode payload =
  match String.split_on_char '\n' payload with
  | [ "TC1"; state_text; checksum_line ] ->
      let prefix = "checksum=" in
      let prefix_length = String.length prefix in
      if String.length checksum_line <= prefix_length
         || not (String.starts_with ~prefix checksum_line)
      then
        Error "missing snapshot checksum"
      else
        let expected =
          String.sub checksum_line prefix_length
            (String.length checksum_line - prefix_length)
        in
        let body = String.concat "\n" [ "TC1"; state_text ] in
        let actual = Digest.to_hex (Digest.string body) in
        if not (String.equal expected actual) then
          Error "snapshot checksum mismatch"
        else
          parse_state state_text
  | version :: _ when not (String.equal version "TC1") ->
      Error "unsupported snapshot format"
  | _ ->
      Error "invalid snapshot shape"
