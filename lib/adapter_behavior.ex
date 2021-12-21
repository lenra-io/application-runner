defmodule ApplicationRunner.AdapterBehavior do
  @moduledoc """
  ApplicationRunner's AdapterBehavior
  """
  alias ApplicationRunner.{EnvState, ListenerContext, SessionState}

  @callback get_manifest(EnvState.t()) :: {:ok, map()} | {:error, map()}
  @callback get_widget(String.t(), map(), map()) :: {:ok, map()} | {:error, map()}
  @callback run_listener(EnvState.t(), ListenerContext.t(), map()) ::
              {:ok, map()} | {:error, map()}
  @callback get_data(SessionState.t()) :: {:ok, map()} | {:error, atom()}
  @callback save_data(SessionState.t(), map()) :: :ok | {:error, atom()}
  @callback on_ui_changed(SessionState.t(), map()) :: :ok
end
