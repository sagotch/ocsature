open%shared Eliom_content.Html.D

module %%%MODULE_NAME%%%_app =
  Eliom_registration.App
    (struct
      let application_name = "%%%MODULE_NAME%%%"
      let global_data_path = None
    end)

let main_service =
  Eliom_service.create
    ~path:(Eliom_service.Path [])
    ~meth:(Eliom_service.Get Eliom_parameter.unit)
    ()

let () =
  %%%MODULE_NAME%%%_app.register ~service:main_service @@ fun () () ->
  let head = head (title @@ pcdata "%%%PROJECT_NAME%%%") [] in
  let body = body [ h1 [ pcdata "Welcome to \"Bien, monsieur.\" template!" ] ] in
  Lwt.return @@ html head body
