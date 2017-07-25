(* Ocsature
 * http://github.com/sagotch/ocsature
 *
 * Copyright (C)
 *   2017 - Julien Sagot
 *
 * Based on Ocsigen-start (http://www.ocsigen.org/ocsigen-start)
 * Copyright (C) Université Paris Diderot, CNRS, INRIA, Be Sport.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, with linking exception;
 * either version 2.1 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *)

exception Not_connected

module type Make_in = sig
  type t
  val to_string : t -> string
  val of_string : string -> t
end

module type Make_out = sig
  type t
  val on_start_process : (unit -> unit Lwt.t) -> unit
  val on_start_connected_process : (t -> unit Lwt.t) -> unit
  val on_connected_request : (t -> unit Lwt.t) -> unit
  val on_open_session : (t -> unit Lwt.t) -> unit
  val on_pre_close_session : (unit -> unit Lwt.t) -> unit
  val on_post_close_session : (unit -> unit Lwt.t) -> unit
  val on_request : (unit -> unit Lwt.t) -> unit
  val on_denied_request : (t option -> unit Lwt.t) -> unit
  val user_indep_state_hierarchy : Eliom_common.scope_hierarchy
  val user_indep_process_scope : Eliom_common.client_process_scope
  val user_indep_session_scope : Eliom_common.session_scope
  val connect : ?expire:bool -> t -> unit Lwt.t
  val disconnect : unit -> unit Lwt.t
  val session_fun : ('a -> 'b -> 'c Lwt.t) -> ('a -> 'b -> 'c Lwt.t)
  val session_rpc : ('a -> 'c Lwt.t) -> ('a -> 'c Lwt.t)
  module Current : sig
    val get : unit -> t
    val get_o : unit -> t option
  end
end

module Make (In : Make_in) = struct

  type t = In.t

  module Current = struct

    let current_ref : t option Eliom_reference.Volatile.eref =
      Eliom_reference.Volatile.eref ~scope:Eliom_common.request_scope None

    let set u =
      Eliom_reference.Volatile.set current_ref (Some u)

    let unset () =
      Eliom_reference.Volatile.set current_ref None

    let get_o () = Eliom_reference.Volatile.get current_ref

    let get () =
      match Eliom_reference.Volatile.get current_ref with
      | Some a -> a
      | None -> raise Not_connected

  end

  let user_indep_state_hierarchy =
    Eliom_common.create_scope_hierarchy "userindep"
  let user_indep_process_scope =
    `Client_process user_indep_state_hierarchy
  let user_indep_session_scope =
    `Session user_indep_state_hierarchy

  let new_process_eref =
    Eliom_reference.Volatile.eref
      ~scope:user_indep_process_scope
      true

  (* Call this to add an action to be done on server side
     when the process starts *)
  let (on_start_process, start_process_action) =
    let r = ref Lwt.return in
    ((fun f ->
       let oldf = !r in
       r := (fun () -> let%lwt () = oldf () in f ())),
     (fun () -> !r ()))

  (* Call this to add an action to be done
     when the process starts in connected mode, or when the user logs in *)
  let (on_start_connected_process, start_connected_process_action) =
    let r = ref (fun x -> Current.set x ; Lwt.return_unit) in
    ((fun f ->
       let oldf = !r in
       r := (fun userid -> let%lwt () = oldf userid in f userid)),
     (fun userid -> !r userid))

  (* Call this to add an action to be done at each connected request *)
  let (on_connected_request, connected_request_action) =
    let r = ref (fun x -> Current.set x ; Lwt.return_unit) in
    ((fun f ->
       let oldf = !r in
       r := (fun userid -> let%lwt () = oldf userid in f userid)),
     (fun userid -> !r userid))

  (* Call this to add an action to be done just after openning a session *)
  let (on_open_session, open_session_action) =
    let r = ref (fun _ -> Lwt.return_unit) in
    ((fun f ->
       let oldf = !r in
       r := (fun userid -> let%lwt () = oldf userid in f userid)),
     (fun userid -> !r userid))

  (* Call this to add an action to be done just after closing the session *)
  let (on_post_close_session, post_close_session_action) =
    let r = ref (fun _ -> Lwt.return_unit) in
    ((fun f ->
       let oldf = !r in
       r := (fun () -> let%lwt () = oldf () in f ())),
     (fun () -> !r ()))

  (* Call this to add an action to be done just before closing the session *)
  let (on_pre_close_session, pre_close_session_action) =
    let r = ref (fun _ -> Current.unset () ; Lwt.return_unit) in
    ((fun f ->
       let oldf = !r in
       r := (fun () -> let%lwt () = oldf () in f ())),
     (fun () -> !r ()))

  (* Call this to add an action to be done just before handling a request *)
  let (on_request, request_action) =
    let r = ref (fun _ -> Current.unset () ; Lwt.return_unit) in
    ((fun f ->
       let oldf = !r in
       r := (fun () -> let%lwt () = oldf () in f ())),
     (fun () -> !r ()))

  (* Call this to add an action to be done just for each denied request *)
  let ((on_denied_request : (t option -> unit Lwt.t) -> unit)
      , denied_request_action) =
    let r = ref (fun _ -> Lwt.return_unit) in
    ((fun f ->
       let oldf = !r in
       r := (fun userid_o -> let%lwt () = oldf userid_o in f userid_o)),
     (fun userid_o -> !r userid_o))

  let connect_volatile uid =
    Eliom_state.set_volatile_data_session_group
      ~scope:Eliom_common.default_session_scope uid;
    let uid = In.of_string uid in
    open_session_action uid

  let connect_string uid =
    let%lwt () = Eliom_state.set_persistent_data_session_group
        ~scope:Eliom_common.default_session_scope uid in
    let%lwt () = connect_volatile uid in
    let uid = In.of_string uid in
    start_connected_process_action uid

  let connect ?(expire = false) userid =
    let%lwt () =
      if expire then begin
        let open Eliom_common in
        let cookie_scope = (default_session_scope :> cookie_scope) in
        Eliom_state.set_service_cookie_exp_date ~cookie_scope None;
        Eliom_state.set_volatile_data_cookie_exp_date ~cookie_scope None;
        Eliom_state.set_persistent_data_cookie_exp_date ~cookie_scope None
      end else
        Lwt.return_unit
    in
    connect_string (In.to_string userid)

  let disconnect () =
    let%lwt () = pre_close_session_action () in
    let%lwt () =
      Eliom_state.discard ~scope:Eliom_common.default_session_scope () in
    let%lwt () =
      Eliom_state.discard ~scope:Eliom_common.default_process_scope () in
    let%lwt () =
      Eliom_state.discard ~scope:Eliom_common.request_scope () in
    post_close_session_action ()

  let get_session () =
    let uids = Eliom_state.get_volatile_data_session_group () in
    let get_uid uid =
      try Eliom_lib.Option.map In.of_string uid
      with Failure _ -> None
    in
    match get_uid uids with
    | None ->
      let%lwt uids = Eliom_state.get_persistent_data_session_group () in
      (match get_uid uids  with
       | Some uid ->
         (* A persistent session exists, but the volatile session has gone.
            It may be due to a timeout or may be the server has been
            relaunched.
            We restart the volatile session silently
            (comme si de rien n'était, pom pom pom). *)
         let%lwt () = connect_volatile (In.to_string uid) in
         Lwt.return_some uid
       | None -> Lwt.return_none)
    | Some uid -> Lwt.return_some uid

  let wrapper fn gp pp =
    let new_process = Eliom_reference.Volatile.get new_process_eref in
    let%lwt uid = get_session () in
    let%lwt () = request_action () in
    let%lwt () =
      if new_process
      then begin
        Eliom_reference.Volatile.set new_process_eref false;
        (* client side process:
           Now we want to do some computation only when we start a
           client side process. *)
        let%lwt () = start_process_action () in
        match uid with
        | None -> Lwt.return_unit
        | Some id -> (* new client process, but already connected *)
          start_connected_process_action id
      end
      else Lwt.return_unit
    in
    let%lwt () =
      match uid with
      | None -> Lwt.return_unit
      | Some id -> connected_request_action id in
    fn gp pp

  let session_fun fn gp pp =  wrapper fn gp pp

  let session_rpc fn pp =  wrapper (fun _ -> fn) () pp

end
