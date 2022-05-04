defmodule ApplicationRunner.AdapterBehavior do
  @moduledoc """
  ApplicationRunner's AdapterBehavior
  """
  alias ApplicationRunner.{
    AST,
    EnvState,
    SessionState
  }

  @type widget() :: map()
  @type manifest() :: map()
  @type data() :: list(map()) | map()
  @type props() :: map()
  @type event() :: map()
  @type reason() :: atom()
  @type ui() :: map()
  @type patches() :: list(map())
  @type action() :: String.t()
  @type widget_name() :: String.t()

  @callback get_manifest(EnvState.t()) :: {:ok, manifest()} | {:error, reason()}
  @callback get_widget(SessionState.t(), widget_name(), data(), props()) ::
              {:ok, widget()} | {:error, reason()}
  @callback run_listener(SessionState.t() | EnvState.t(), action(), props(), event()) ::
              :ok | {:error, reason()} | :error404
  @callback exec_query(SessionState.t(), AST.Query.t()) :: data()
  @callback create_user_data(SessionState.t()) :: :ok | {:error, reason()}
  @callback first_time_user?(SessionState.t()) :: boolean()
  @callback on_ui_changed(
              SessionState.t(),
              {:ui, ui()} | {:patches, patches()} | {:error, tuple() | String.t()}
            ) :: :ok
end
