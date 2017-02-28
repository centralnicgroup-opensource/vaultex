use Mix.Config


config :vaultex, 
  app_id:    "foo",
  role_id:   File.read!(".role_id") |> String.trim,
  secret_id: File.read!(".secret_id") |> String.trim
