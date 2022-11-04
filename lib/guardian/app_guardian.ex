defmodule ApplicationRunner.Guardian.AppGuardian do
  @moduledoc """
    ApplicationRunner.Guardian.AppGuardian handle the callback operations to generate and verify the token.
  """
  use Guardian, otp_app: :application_runner

  alias ApplicationRunner.{
    Environment,
    MongoStorage,
    Session
  }

  require Logger

  alias ApplicationRunner.Errors.{BusinessError, TechnicalError}

  def subject_for_token(session_pid, _claims) do
    {:ok, to_string(session_pid)}
  end

  def resource_from_claims(%{"user_id" => user_id, "env_id" => env_id}) do
    env = MongoStorage.get_env!(env_id)
    user = MongoStorage.get_user!(user_id)
    mongo_user_link = MongoStorage.get_mongo_user_link!(env_id, user_id)

    {:ok, %{environment: env, user: user, mongo_user_link: mongo_user_link}}
  end

  def resource_from_claims(%{"env_id" => env_id}) do
    env = MongoStorage.get_env!(env_id)
    {:ok, %{environment: env}}
  end

  def resource_from_claims(_) do
    raise "Claims not matching."
  end

  def on_verify(claims, token, _options) do
    if get_app_token(claims) == token do
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
        Environment.fetch_token(String.to_integer(claims["sub"]))

      _err ->
        TechnicalError.unknown_error_tuple()
    end
  end
end
