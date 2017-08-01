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

module type Make_in = sig
  type t
  val to_string : t -> string
  val of_string : string -> t
end

module type Make_out = sig

  type t

  (** Connection and disconnection of users,
      restrict access to services or server functions,
      define actions to be executed at some points of the session. *)

  (** Call this to add an action to be done on server side
      when the process starts *)
  val on_start_process : (unit -> unit Lwt.t) -> unit

  (** Call this to add an action to be done
      when the process starts in connected mode, or when the user logs in *)
  val on_start_connected_process : (t -> unit Lwt.t) -> unit

  (** Call this to add an action to be done at each connected request.
      The function takes the user id as parameter. *)
  val on_connected_request : (t -> unit Lwt.t) -> unit

  (** Call this to add an action to be done just after opening a session
      The function takes the user id as parameter. *)
  val on_open_session : (t -> unit Lwt.t) -> unit

  (** Call this to add an action to be done just before closing the session *)
  val on_pre_close_session : (unit -> unit Lwt.t) -> unit

  (** Call this to add an action to be done just after closing the session *)
  val on_post_close_session : (unit -> unit Lwt.t) -> unit

  (** Call this to add an action to be done just before handling a request *)
  val on_request : (unit -> unit Lwt.t) -> unit

  (** Call this to add an action to be done just for each denied request.
      The function takes the user id as parameter, if some user is connected. *)
  val on_denied_request : (t option -> unit Lwt.t) -> unit

  (** Scopes that are independant from user connection.
      Use this scopes for example when you want to store
      server side data for one browser or tab, but not user dependant.
      (Remains when user logs out).
  *)
  val user_indep_state_hierarchy : Eliom_common.scope_hierarchy
  val user_indep_process_scope : Eliom_common.client_process_scope
  val user_indep_session_scope : Eliom_common.session_scope

  (** Open a session for a user by setting a session group for the browser
      which initiated the current request.
      Ocsigen-start is using both persistent and volatile session groups.
      The volatile groups is recreated from persistent group if absent.
      By default, the connection does not expire; by setting the optional
      argument [expire] to true, the session will expire when the browser
      exits.
  *)
  val connect : ?expire:bool -> t -> unit Lwt.t

  (** Close a session by discarding server side states for current browser
      (session and session group), current client process (tab) and current
      request.
      Only default Eliom scopes are affected, but not user independant scopes.
      The actions registered for session close (by {!on_close_session})
      will be executed just before the session is actually closed.
  *)
  val disconnect : unit -> unit Lwt.t

  (** Wrapper for service handlers that fetches automatically connection
      information.
      Register [(connected_fun f)] as handler for your services,
      where [f] is a function taking user id, GET parameters and POST parameters.
      If no user is connected, the service will fail by raising [Not_connected].
      Otherwise it calls function [f].
      To provide another behaviour in case the user is not connected,
      have a look at {!Opt.connected_fun} or module {!Ocsature_page}.

      No security check is done.

      Use only one connection wrapper for each request!
  *)
  val session_fun : ('a -> 'b -> 'c Lwt.t) -> ('a -> 'b -> 'c Lwt.t)
  val session_rpc : ('a -> 'c Lwt.t) -> ('a -> 'c Lwt.t)

  module Current : sig
    val get : unit -> t
    val get_o : unit -> t option
  end

end

module Make : functor (In : Make_in) -> Make_out with type t = In.t

[%%client.start]

module type Make_in = sig
  type t
end

module type Make_out = sig
  type t
  module Current : sig
    val get : unit -> t
    val get_o : unit -> t option
    val set : t -> unit
    val unset : unit -> unit
  end
  val session_fun : ('a -> 'b -> 'c Lwt.t) -> ('a -> 'b -> 'c Lwt.t)
end

module Make : functor (In : Make_in) -> Make_out with type t = In.t
