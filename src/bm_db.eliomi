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

module PGOCaml : PGOCaml_generic.PGOCAML_GENERIC with type 'a monad = 'a Lwt.t

module type Db_query_out = sig
  open PGOCaml
  val query : string -> param list -> (row list -> 'a Lwt.t) -> 'a Lwt.t
  val exec : string -> param list -> unit Lwt.t
  val all : string -> param list -> row list Lwt.t
  val one : string -> param list -> row Lwt.t
  val exists : string -> param list -> bool Lwt.t
  val not_exists : string -> param list -> bool Lwt.t
end

module type Bm_db_in = sig
  val host : string option
  val port : int option
  val user : string option
  val password : string option
  val database : string option
  val unix_domain_socket_dir : string option
  val pool_size : int
end

module type Bm_db_out = sig
  module WithTransaction : Db_query_out
  module WithoutTransaction : Db_query_out
end

module Make (A : Bm_db_in) : Bm_db_out
