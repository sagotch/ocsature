open%shared Eliom_content.Html.F

let%shared make_uri = function
  | `Local path ->
    make_uri ~absolute:false ~service:(Eliom_service.static_dir ()) path
  | `External path ->
    uri_of_string (fun () -> path)

let%shared js_ uri = js_script ~a:[ a_defer () ] ~uri:(make_uri uri) ()

let%shared css_ uri = css_link ~uri:(make_uri uri) ()

let%shared page ?a ?(js = []) ?(css = []) ~title:t ?(head = []) content =
  let head =
    Eliom_content.Html.F.head (title @@ pcdata t) @@
    List.rev_append
      (List.rev_append (List.map css_ css) (List.rev_map js_ js))
      head in
  html ?a head (body content)
