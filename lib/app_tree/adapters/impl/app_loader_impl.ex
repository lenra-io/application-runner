defmodule ApplicationRunner.AppLoaderImpl do
  @moduledoc """
    Fake implementation of AppLoaderAdapter for test purpose
  """
  @behaviour ApplicationRunner.AppLoaderAdapter

  @impl true
  def load_app_state(app_id) do
    {:ok, %{app_id: app_id, app_name: "TestApp", version: "1.0"}}
  end
end
