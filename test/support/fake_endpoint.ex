defmodule ApplicationRunner.FakeEndpoint do
  use Phoenix.Endpoint, otp_app: :application_runner

  # Sentry stuff to capture errors

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_lenra_key",
    signing_salt: "MFyEizGS"
  ]

  plug(Plug.RequestId)

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)
  plug(Plug.Session, @session_options)

  plug(ApplicationRunner.FakeRouter)
end
