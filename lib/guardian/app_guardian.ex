defmodule ApplicationRunner.Guardian.AppGuardian do
  @moduledoc """
    ApplicationRunner.Guardian.AppGuardian handle the callback operations to generate and verify the token.
  """

  use Guardian, otp_app: :application_runner

  alias ApplicationRunner.{
    Contract,
    Environments,
    Session
  }

  alias ApplicationRunner.Errors.{BusinessError, TechnicalError}

  @repo Application.compile_env(:application_runner, :repo)

  def subject_for_token(session_pid, _claims) do
    {:ok, to_string(session_pid)}
  end

  def resource_from_claims(%{"user_id" => user_id, "env_id" => env_id}) do
    with env <- @repo.get(Contract.Environment, env_id),
         user <- @repo.get(Contract.User, user_id) do
      {:ok, %{environment: env, user: user}}
    end
  end

  def resource_from_claims(%{"env_id" => env_id}) do
    with env <- @repo.get(Contract.Environment, env_id) do
      {:ok, %{environment: env}}
    end
  end

  def on_verify(claims, token, _options) do
    if get_app_token(claims) ==
         token do
      {:ok, claims}
    else
      BusinessError.invalid_token_tuple()
    end
  end

  defp get_app_token(claims) do
    case claims["type"] do
      "session" ->
        Session.fetch_token(claims["sub"])

      "env" ->
        Environments.Token.fetch_token(String.to_integer(claims["sub"]))

      _err ->
        TechnicalError.unknown_error_tuple()
    end
  end
end