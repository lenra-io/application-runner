defmodule ApplicationRunner.AdapterBehavior do
  @moduledoc """
  ApplicationRunner's AdapterBehavior
  """
  alias ApplicationRunner.{EnvState, ListenerContext}

  @callback get_manifest(EnvState.t()) :: {:ok, map()} | {:error, map()}
  @callback get_widget(String.t(), map(), map()) :: {:ok, map()} | {:error, map()}
  @callback run_listener(EnvState.t(), ListenerContext.t(), map()) ::
              {:ok, map()} | {:error, map()}
  @callback get_data(EnvState.t()) :: {:ok, map()} | {:error, atom()}
  @callback save_data(EnvState.t(), map()) :: :ok | {:error, atom()}
  @callback on_ui_changed(map()) :: :ok
end
