[%%shared.start]

open Eliom_content.Html
open Html_types

val page
  : ?a:html_attrib attrib list
  -> ?js:[ `External of string | `Local of string list ] list
  -> ?css:[ `External of string | `Local of string list ] list
  -> title:string
  -> body_content elt list
  -> [> html ] elt
