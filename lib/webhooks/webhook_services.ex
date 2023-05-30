defmodule ApplicationRunner.Webhooks.WebhookServices do
  @moduledoc """
    The service that manages the webhooks.
  """

  import Ecto.Query, only: [from: 2]

  alias ApplicationRunner.ApplicationServices
  alias ApplicationRunner.Environment
  alias ApplicationRunner.Environment.MetadataAgent
  alias ApplicationRunner.Errors.TechnicalError
  alias ApplicationRunner.Guardian.AppGuardian
  alias ApplicationRunner.Webhooks.Webhook

  @repo Application.compile_env(:application_runner, :repo)

  def create(env_id, params) do
    Webhook.new(env_id, params)
    |> @repo.insert()
  end

  def app_create(
        %{
          environment: %ApplicationRunner.Contract.Environment{id: env_id},
          user: %ApplicationRunner.Contract.User{id: user_id}
        },
        params
      ) do
    create(env_id, Map.merge(params, %{"user_id" => user_id}))
  end

  def app_create(%{environment: %ApplicationRunner.Contract.Environment{id: env_id}}, params) do
    create(env_id, params)
  end

  def get(env_id) do
    @repo.all(from(w in Webhook, where: w.environment_id == ^env_id))
  end

  def get(env_id, user_id) do
    @repo.all(from(w in Webhook, where: w.environment_id == ^env_id and w.user_id == ^user_id))
  end

  def get_by_uuid(uuid) do
    @repo.get(Webhook, uuid)
  end

  def trigger(webhook_uuid, payload) do
    case @repo.get(Webhook, webhook_uuid) do
      nil ->
        TechnicalError.error_404_tuple()

      webhook ->
        metadata = MetadataAgent.get_metadata(webhook.environment_id)

        uuid = Ecto.UUID.generate()

        {:ok, token, _claims} =
          AppGuardian.encode_and_sign(uuid, %{type: "env", env_id: webhook.environment_id})

        Environment.TokenAgent.add_token(webhook.environment_id, uuid, token)

        ApplicationServices.run_listener(
          metadata.function_name,
          webhook.action,
          webhook.props,
          payload,
          token
        )

        Environment.TokenAgent.revoke_token(webhook.environment_id, uuid)
    end
  end
end
