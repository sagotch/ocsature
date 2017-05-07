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

[%%server.start]

module type Make_out = sig

  type userid
  type user

  exception Already_exists of userid

  exception No_such_user

  val verify_password
    : signature:string -> password:string -> userid Lwt.t

  val userid_of_signature : string -> userid Lwt.t

  val create : ?password:string -> string -> user Lwt.t

  val update_password
    : userid:userid -> password:string -> unit Lwt.t

end

module type TableConfig = sig
  type user
  type userid
  val userid_to_string : userid -> string
  val userid_of_string : string -> userid
  val user_table : string
  val user_table_userid : string
  val user_table_signature : string
  val user_table_password : string
  val user_of_row : Bm_db.PGOCaml.row -> user
end

module DefaultUserTable : TableConfig

module Make : functor (_ : Bm_db.Bm_db_out) (T : TableConfig) ->
  Make_out with type user = T.user
            and type userid = T.userid
