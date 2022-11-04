defmodule ApplicationRunner.Guardian.EnsureAuthenticatedAppPipeline do
  @moduledoc """
    This pipeline ensure that the user is authenticated with an access_token and load the resource associated.
  """

  @otp_app Application.compile_env(:application_runner, :otp_app)
  use Guardian.Plug.Pipeline,
    otp_app: @otp_app,
    error_handler: ApplicationRunner.Guardian.ErrorHandler,
    module: ApplicationRunner.Guardian.AppGuardian

  plug(Guardian.Plug.VerifyHeader, claims: %{"typ" => "access"})
  plug(Guardian.Plug.EnsureAuthenticated, claims: %{"typ" => "access"})
  plug(Guardian.Plug.LoadResource)
end
