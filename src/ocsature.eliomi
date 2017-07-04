[%%server.start]

module Db : module type of Ocsature_db
module Page : module type of Ocsature_page
module Password : module type of Ocsature_password
module RequestCache : module type of Ocsature_request_cache
module Session : module type of Ocsature_session
module User : module type of Ocsature_user

[%%client.start]

module Page : module type of Ocsature_page
