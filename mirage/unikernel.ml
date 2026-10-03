open Cmdliner
let port =
  let doc = Arg.info ~doc:"Port of the TimeCapsule HTTP service." [ "p"; "port" ] in
  Arg.(value & opt int 8080 doc)

module Make (HTTP_server : Paf_mirage.S with type ipaddr = Ipaddr.t) = struct
  module Capsule = Timecapsule_core.Time_capsule

  let current = ref Capsule.Unsealed
  let mutation_lock = Lwt_mutex.create ()

  let timestamp_now () =
    Mirage_ptime.now ()
    |> Ptime.to_float_s
    |> Int64.of_float

  let state_json = function
    | Capsule.Unsealed ->
        {|{"state":"unsealed"}
|}
    | Capsule.Waiting { deadline } ->
        Printf.sprintf
          {|{"state":"waiting","deadline":%Ld}
|}
          deadline
    | Capsule.Released { deadline; released_at } ->
        Printf.sprintf
          {|{"state":"released","deadline":%Ld,"released_at":%Ld}
|}
          deadline
          released_at

  let refusal_json = function
    | Capsule.Not_sealed ->
        {|{"error":"not_sealed"}
|}
    | Capsule.Too_early { deadline; observed_at } ->
        Printf.sprintf
          {|{"error":"too_early","deadline":%Ld,"observed_at":%Ld}
|}
          deadline
          observed_at
    | Capsule.Deadline_conflict { existing_deadline; requested_deadline } ->
        Printf.sprintf
          {|{"error":"deadline_conflict","existing_deadline":%Ld,"requested_deadline":%Ld}
|}
          existing_deadline
          requested_deadline

  let respond reqd status body =
    let headers =
      H1.Headers.of_list
        [ ("content-length", string_of_int (String.length body))
        ; ("content-type", "application/json")
        ; ("connection", "close")
        ]
    in
    let response = H1.Response.create ~headers status in
    H1.Reqd.respond_with_string reqd response body

  let apply reqd command =
    match Capsule.step !current command with
    | Capsule.Applied state ->
        current := state;
        respond reqd `OK (state_json state)
    | Capsule.Unchanged state ->
        respond reqd `OK (state_json state)
    | Capsule.Refused refusal ->
        respond reqd `Conflict (refusal_json refusal)

  let parse_deadline target =
    let prefix = "/seal?deadline=" in
    let prefix_len = String.length prefix in
    if String.length target <= prefix_len
       || not (String.starts_with ~prefix target)
    then
      None
    else
      let raw =
        String.sub target prefix_len (String.length target - prefix_len)
      in
      if String.contains raw '&' then None
      else Int64.of_string_opt raw

  let request_handler _flow (_ipaddr, _port) reqd =
    let request = H1.Reqd.request reqd in
    H1.Body.Reader.close (H1.Reqd.request_body reqd);
    match request.H1.Request.meth, request.H1.Request.target with
    | `GET, "/state" ->
        respond reqd `OK (state_json !current)
    | `POST, target when String.starts_with ~prefix:"/seal?deadline=" target ->
        (match parse_deadline target with
         | None ->
             respond reqd `Bad_request {|{"error":"invalid_deadline"}
|}
         | Some deadline ->
             Lwt.async (fun () ->
               Lwt_mutex.with_lock mutation_lock (fun () ->
                 apply reqd (Capsule.Seal deadline);
                 Lwt.return_unit)))
    | `POST, "/release" ->
        Lwt.async (fun () ->
          Lwt_mutex.with_lock mutation_lock (fun () ->
            let observed_at = timestamp_now () in
            apply reqd (Capsule.Release observed_at);
            Lwt.return_unit))
    | _ ->
        respond reqd `Not_found {|{"error":"not_found"}
|}

  let error_handler (_ipaddr, _port) ?request:_ _error _send = ()

  let start http_server =
    let service =
      HTTP_server.http_service
        ~error_handler
        request_handler
    in
    let (`Initialized thread) = Paf.serve service http_server in
    thread
end
