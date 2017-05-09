(* Bien, monsieur !
 * http://github.com/sagotch/bien-monsieur
 *
 * Copyright (C)
 *   2017 - Julien Sagot
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

exception No_such_resource

module PGOCaml = PGOCaml_generic.Make(struct
    include Lwt
    let close_in = Lwt_io.close
    let really_input = Lwt_io.read_into_exactly
    let input_binary_int = Lwt_io.BE.read_int
    let input_char = Lwt_io.read_char
    let output_string = Lwt_io.write
    let output_binary_int = Lwt_io.BE.write_int
    let output_char = Lwt_io.write_char
    let flush = Lwt_io.flush
    let open_connection x = Lwt_io.open_connection x
    type out_channel = Lwt_io.output_channel
    type in_channel = Lwt_io.input_channel
  end)

module type Bm_db_in = sig
  val host : string option
  val port : int option
  val user : string option
  val password : string option
  val database : string option
  val unix_domain_socket_dir : string option
  val pool_size : int
end

module type Db_query_in = sig
  val f : (PGOCaml.pa_pg_data PGOCaml.t -> 'a Lwt.t) -> 'a Lwt.t
end

module type Db_query_out = sig
  open PGOCaml
  val query : string -> param list -> (row list -> 'a Lwt.t) -> 'a Lwt.t
  val exec : string -> param list -> unit Lwt.t
  val all : string -> param list -> row list Lwt.t
  val one : string -> param list -> row Lwt.t
  val exists : string -> param list -> bool Lwt.t
  val not_exists : string -> param list -> bool Lwt.t
end

module Db_query (F : Db_query_in) : Db_query_out = struct

  let query q a f =
    F.f @@ fun h ->
    let%lwt () = PGOCaml.prepare h ~query:q () in
    let%lwt r = PGOCaml.execute h a () in
    let%lwt () = PGOCaml.close_statement h () in
    f r

  let exec q a =
    query q a (fun _ -> Lwt.return_unit)

  let all q a = query q a Lwt.return

  let one q a =
    query q a
      (function x :: _ -> Lwt.return x | _ -> Lwt.fail No_such_resource)

  let exists q a =
    query q a (fun x -> Lwt.return (x <> []))

  let not_exists q a =
    query q a (fun x -> Lwt.return (x = []))

end

module type Bm_db_out = sig
  module WithTransaction : Db_query_out
  module WithoutTransaction : Db_query_out
end

module Make (A : Bm_db_in) = struct

  let connect () =
    PGOCaml.connect
      ?host:A.host
      ?port:A.port
      ?user:A.user
      ?password:A.password
      ?database:A.database
      ?unix_domain_socket_dir:A.unix_domain_socket_dir
      ()

  let validate db =
    try%lwt let%lwt () = PGOCaml.ping db in Lwt.return_true
    with _ -> Lwt.return_false

  let pool : (string, bool) Hashtbl.t PGOCaml.t Lwt_pool.t =
    Lwt_pool.create A.pool_size ~validate connect

  let with_transaction f =
    Lwt_pool.use pool @@ fun db ->
    let%lwt () = PGOCaml.begin_work db in
    try%lwt
      let%lwt r = f db in
      let%lwt () = PGOCaml.commit db in
      Lwt.return r
    with e ->
      let%lwt () = PGOCaml.rollback db in
      Lwt.fail e

  let without_transaction f = Lwt_pool.use pool (fun db -> f db)

  module WithTransaction = Db_query(struct let f = with_transaction end)
  module WithoutTransaction = Db_query(struct let f = without_transaction end)

end
