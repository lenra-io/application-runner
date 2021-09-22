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
         {:ok, final_ui} <-
           run_app_listener(%{action | action_name: "InitData", props: %{}, event: %{}}) do
      {:ok, final_ui}
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

  @spec build_ui(ui()) :: {:ok, ui()} | {:error, String.t()}
  defp build_ui(%{"root" => base_component} = ui) do
    with {:ok, builded_base_component} <- rec_build_ui(base_component) do
      {:ok, Map.put(ui, "root", builded_base_component)}
    end
  end

  @spec rec_build_ui(map()) :: {:ok, map()} | {:error, String.t()}
  def rec_build_ui(component)

  @doc """
    Build recursively the given component and return the builded component.
    The UI can be :
     - A container -> The function will build all children recursively
     - A listener component -> The function will build the listener
     - Any other : Nothing happend, return self.
  """

  # Container case. Run recursivly for all children. Return builded container with updated children
  def rec_build_ui(%{"children" => children} = container) when is_list(children) do
    Enum.reduce_while(children, {:ok, []}, fn child, {:ok, acc} ->
      case rec_build_ui(child) do
        {:ok, new_child} -> {:cont, {:ok, acc ++ [new_child]}}
        {:error, _} = err -> {:halt, err}
      end
    end)
    |> case do
      {:ok, new_children} -> {:ok, Map.put(container, "children", new_children)}
      err -> err
    end
  end

  # listener case. Save all listeners and return modified listener element with data replacement
  def rec_build_ui(%{"listeners" => listeners_map} = component) when is_map(listeners_map) do
    with {:ok, new_listeners} <- save_and_encode_listeners(listeners_map) do
      {
        :ok,
        Map.put(component, "listeners", new_listeners)
      }
    end
  end

  # Base case, return same component
  def rec_build_ui(component) do
    {:ok, component}
  end

  @spec save_and_encode_listeners(map()) :: {:ok, map()} | {:error, String.t()}
  defp save_and_encode_listeners(listeners_map) do
    Enum.reduce_while(
      listeners_map,
      {:ok, %{}},
      fn
        {event_name, %{"action" => action_code} = listener}, {:ok, acc} ->
          props = Map.get(listener, "props", %{})
          listener_key = Storage.generate_listeners_key(action_code, props)
          Storage.insert(:listeners, listener_key, listener)
          {:cont, {:ok, Map.put(acc, event_name, %{"code" => listener_key})}}

        _, _ ->
          {:halt, {:error, "All listener must have an action name."}}
      end
    )
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
