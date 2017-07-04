let crypt password =
  Bcrypt.string_of_hash (Bcrypt.hash password)

let verify password1 password2 =
  Bcrypt.verify password1 (Bcrypt.hash_of_string password2)
