(* Ocsature
 * http://github.com/sagotch/ocsature
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

module type Make_out = sig
  type user
  type userid
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
  val user_of_row : Ocsature_db.PGOCaml.row -> user
end

module DefaultUserTable = struct
  type user = (int64 * string)
  type userid = int64
  let userid_to_string = PGOCaml.string_of_int64
  let userid_of_string = PGOCaml.int64_of_string
  let user_table = "users"
  let user_table_userid = "userid"
  let user_table_signature = "signature"
  let user_table_password = "password"
  let user_of_row = function
    | [ Some userid ; Some signature ] ->
      (userid_of_string userid, signature)
    | _ -> assert false
end

module Make (DB : Ocsature_db.Ocsature_db_out) (T : TableConfig) = struct

  type user = T.user
  type userid = T.userid

  open Eliom_content.Html.F

  exception Already_exists of userid
  exception No_such_user

  let available signature =
    DB.WithoutTransaction.not_exists
      ("SELECT 1 FROM " ^ T.user_table
       ^ " WHERE " ^ T.user_table_signature ^ " = $1")
      [ Some signature ]

  let userid_of_signature signature =
    DB.WithoutTransaction.one
      ("SELECT " ^ T.user_table_userid ^ " FROM " ^ T.user_table
       ^ " WHERE " ^ T.user_table_signature ^ " = $1")
      [ Some signature ]
    |> Lwt.map (fun [ Some userid ] -> T.userid_of_string userid)
      [@ocaml.warning "-8"]

  let create ?password signature =
    if password = Some "" then Lwt.fail_with "Empty password"
    else
      DB.WithoutTransaction.one
        ("INSERT INTO " ^ T.user_table
         ^ " (" ^ T.user_table_signature ^ ", " ^ T.user_table_password ^ ")
         VALUES ($1,$2)
         RETURNING " ^ T.user_table_userid ^ "")
        [ Some signature
        ; Eliom_lib.Option.map Ocsature_password.crypt password ]
      |> Lwt.map (fun [ Some userid ] -> T.userid_of_string userid)
        [@ocaml.warning "-8"]

  let update_password ~userid ~password =
    if password = "" then Lwt.fail_with "Empty password"
    else
      DB.WithoutTransaction.exec
        ("UPDATE " ^ T.user_table ^ "
          SET " ^ T.user_table_password ^ " = $1
          WHERE " ^ T.user_table_userid ^ " = $2")
        [ Some (Ocsature_password.crypt password)
        ; Some (T.userid_to_string userid) ]

  let verify_password ~signature ~password =
    if password = "" then Lwt.fail_with "Empty password"
    else
      DB.WithoutTransaction.query
        ("SELECT " ^ T.user_table_userid ^ ", " ^ T.user_table_password ^ "
          FROM " ^ T.user_table ^ "
          WHERE " ^ T.user_table_signature ^ " = $1")
        [ Some signature ]
        (function
          | [ [ Some userid ; Some p ] ]
            when Ocsature_password.verify password p ->
            Lwt.return (T.userid_of_string userid)
          | _ -> Lwt.fail Ocsature_db.No_such_resource)

  let user_of_userid userid =
    DB.WithoutTransaction.one
      ("SELECT * FROM " ^ T.user_table ^ "
        WHERE " ^ T.user_table_userid ^ " = $1")
      [ Some (T.userid_to_string userid) ]
    |> Lwt.map T.user_of_row

  let create ?password signature =
    try%lwt
      let%lwt userid = userid_of_signature signature in
      Lwt.fail (Already_exists userid)
    with Ocsature_db.No_such_resource ->
      let%lwt userid = create ?password signature in
      user_of_userid userid

end
