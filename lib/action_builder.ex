defmodule ApplicationRunner.ActionBuilder do
  @moduledoc """
    The service to build an app based on a listener.
  """

  require Logger

  alias ApplicationRunner.{Action, Storage}

  @type ow_info :: {String.t(), String.t()}
  @type event :: map()
  @type ui :: map()
  @type ui_patch :: list(map())

  @spec first_run(Action.t()) :: {:ok, ui()} | {:error, String.t()}

  @doc """
    This function build the first UI with default Entry Point `"InitData"` to generate the data model and `"MainUi"` to generate the UI
  """
  def first_run(%Action{} = action) do
    with {:ok, action} <- get_data(action),
         {:ok, _final_ui} = res <-
           run_app_listener(%{action | action_name: "InitData", props: %{}, event: %{}}) do
      res
    end
  end

  @doc """
    This function build the UI using the given `action_key` to generate the data model and `"MainUi"` to generate the UI
  """
  @spec listener_run(Action.t()) ::
          {:ok, ui_patch()} | {:error, String.t()}

  def listener_run(%Action{} = action) do
    with {:ok, action} <- get_data(action),
         {:ok, action} <- get_listener(action),
         {:ok, last_final_ui} <- get_last_final_ui(action),
         {:ok, final_ui} <-
           run_app_listener(action),
         patch <- JSONDiff.diff(last_final_ui, final_ui) do
      {:ok, patch}
    end
  end

  def listener_run(_), do: raise("This is not an action struct.")

  @spec save_final_ui(Action.t(), ui()) :: {:ok, ui()}
  defp save_final_ui(action, final_ui) do
    final_ui_key = Storage.generate_final_ui_key(action.user_id, action.app_name)
    Storage.insert(:final_ui, final_ui_key, final_ui)
    {:ok, final_ui}
  end

  @spec get_last_final_ui(Action.t()) :: {:ok, ui()} | {:error, String.t()}
  defp get_last_final_ui(action) do
    final_ui_key = Storage.generate_final_ui_key(action.user_id, action.app_name)

    case Storage.get(:final_ui, final_ui_key) do
      nil -> {:error, "Could not get Old Final Ui"}
      final_ui -> {:ok, final_ui}
    end
  end

  @spec run_app_listener(Action.t()) :: {:ok, ui()} | {:error, String.t()}
  defp run_app_listener(action) do
    with {:ok, %{"data" => data, "ui" => ui}} <-
           run_action(action),
         {:ok, final_ui} <- ApplicationRunner.UIValidator.validate_and_build(ui),
         {:ok, _} <- save_final_ui(action, final_ui),
         {:ok, _} <- save_data(action, data) do
      {:ok, final_ui}
    end
  end

  @spec get_listener(Action.t()) :: {:ok, Action.t()} | {:error, String.t()}
  defp get_listener(%Action{action_key: action_key} = action) do
    case Storage.get(:listeners, action_key) do
      %{"action" => name, "props" => props} ->
        {:ok, %{action | action_name: name, props: props}}

      %{"action" => name} ->
        {:ok, %{action | action_name: name, props: %{}}}

      nil ->
        {:error, "No Listener Found"}
    end
  end

  @behaviour ApplicationRunner.AdapterBehavior
  defdelegate run_action(action),
    to: Application.fetch_env!(:application_runner, :adapter)

  defdelegate get_data(action), to: Application.fetch_env!(:application_runner, :adapter)
  defdelegate save_data(action, data), to: Application.fetch_env!(:application_runner, :adapter)
end
