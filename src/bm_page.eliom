open%shared Eliom_content.Html.F

let%shared make_uri = function
  | `Local path ->
    make_uri ~absolute:false ~service:(Eliom_service.static_dir ()) path
  | `External path ->
    uri_of_string (fun () -> path)

let%shared js_ uri = js_script ~a:[ a_defer () ] ~uri:(make_uri uri) ()

let%shared css_ uri = css_link ~uri:(make_uri uri) ()

let%shared page ?a ?(js = []) ?(css = []) ~title:t content =
  let head =
    head (title @@ pcdata t) @@ (List.map js_ js @ List.map css_ css) in
  html ?a head (body content)
