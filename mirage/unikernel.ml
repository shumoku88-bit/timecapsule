open Cmdliner
open Lwt.Infix

let port =
  let doc = Arg.info ~doc:"Port of the TimeCapsule HTTP service." [ "p"; "port" ] in
  Arg.(value & opt int 8080 doc)

let program_block_size =
  let doc =
    Arg.info
      ~doc:"Program block size used by the Chamelon persistent store."
      [ "program-block-size" ]
  in
  Arg.(value & opt int 16 doc)

module Make
    (HTTP_server : Paf_mirage.S with type ipaddr = Ipaddr.t)
    (Store : Mirage_kv.RW) =
struct
  module Capsule = Timecapsule_core.Time_capsule
  module Snapshot = Timecapsule_core.Snapshot

  let capsule_key = Mirage_kv.Key.v "/capsule"
  let current = ref Capsule.Unsealed
  let blocked = ref false
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

  let json_storage_error () =
    {|{"error":"storage_unavailable"}
|}

  let fail_storage reqd message =
    blocked := true;
    Logs.err (fun log -> log "%s" message);
    respond reqd `Internal_server_error (json_storage_error ())

  let commit store state =
    Store.set store capsule_key (Snapshot.encode state)

  let apply store reqd command =
    match Capsule.step !current command with
    | Capsule.Applied state ->
        commit store state >>= (function
          | Ok () ->
              current := state;
              respond reqd `OK (state_json state);
              Lwt.return_unit
          | Error error ->
              fail_storage reqd
                (Fmt.str "persistent commit failed: %a"
                   Store.pp_write_error error);
              Lwt.return_unit)
    | Capsule.Unchanged state ->
        respond reqd `OK (state_json state);
        Lwt.return_unit
    | Capsule.Refused refusal ->
        respond reqd `Conflict (refusal_json refusal);
        Lwt.return_unit

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

  let request_handler store _flow (_ipaddr, _port) reqd =
    let request = H1.Reqd.request reqd in
    H1.Body.Reader.close (H1.Reqd.request_body reqd);
    if !blocked then
      respond reqd `Internal_server_error (json_storage_error ())
    else
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
                   apply store reqd (Capsule.Seal deadline))))
      | `POST, "/release" ->
          Lwt.async (fun () ->
            Lwt_mutex.with_lock mutation_lock (fun () ->
              let observed_at = timestamp_now () in
              apply store reqd (Capsule.Release observed_at)))
      | _ ->
          respond reqd `Not_found {|{"error":"not_found"}
|}

  let error_handler (_ipaddr, _port) ?request:_ _error _send = ()

  let load store =
    Store.get store capsule_key >>= function
    | Ok payload ->
        (match Snapshot.decode payload with
         | Ok state ->
             Logs.info (fun log -> log "restored durable TimeCapsule state");
             Lwt.return state
         | Error error ->
             let message =
               Printf.sprintf "invalid persisted capsule snapshot: %s" error
             in
             Logs.err (fun log -> log "%s" message);
             Lwt.fail_with message)
    | Error (`Not_found _) ->
        let state = Capsule.Unsealed in
        commit store state >>= (function
          | Ok () ->
              Logs.info (fun log -> log "initialized fresh durable TimeCapsule");
              Lwt.return state
          | Error error ->
              Lwt.fail_with
                (Fmt.str "initial persistent commit failed: %a"
                   Store.pp_write_error error))
    | Error error ->
        Lwt.fail_with
          (Fmt.str "persistent load failed: %a" Store.pp_error error)

  let start http_server store =
    load store >>= fun state ->
    current := state;
    let service =
      HTTP_server.http_service
        ~error_handler
        (request_handler store)
    in
    let (`Initialized thread) = Paf.serve service http_server in
    thread
end
