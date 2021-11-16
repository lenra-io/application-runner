defmodule ApplicationRunner.AdapterBehavior do
  @moduledoc """
  ApplicationRunner's AdapterBehavior
  """
  alias ApplicationRunner.{AppContext, WidgetContext}

  @callback get_manifest(AppContext.t()) :: {:ok, map()} | {:error, map()}
  @callback get_widget(AppContext.t(), WidgetContext.t(), map()) :: {:ok, map()} | {:error, map()}
  @callback run_listener(AppContext.t(), ListenerContext.t(), map()) :: {:ok, map()} | {:error, map()}
  @callback get_data(Action.t()) :: {:ok, Action.t()}
  @callback save_data(Action.t(), map()) :: {:ok, map()} | {:error, map()}
end
