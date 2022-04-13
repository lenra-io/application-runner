defmodule ApplicationRunner.AdapterBehavior do
  @moduledoc """
  ApplicationRunner's AdapterBehavior
  """
  alias ApplicationRunner.{EnvState, SessionState, AST}

  @type widget() :: map()
  @type manifest() :: map()
  @type data() :: list(map())
  @type props() :: map()
  @type event() :: map()
  @type reason() :: atom()
  @type ui() :: map()
  @type patches() :: list(map())
  @type action() :: String.t()
  @type widget_name() :: String.t()

  @callback get_manifest(EnvState.t()) :: {:ok, manifest()} | {:error, reason()}
  @callback get_widget(EnvState.t(), widget_name(), data(), props()) ::
              {:ok, widget()} | {:error, reason()}
  @callback run_listener(SessionState.t() | EnvState.t(), action(), props(), event()) ::
              :ok | {:error, reason()}
  @callback exec_query(SessionState.t(), AST.Query.t()) :: data()
  @callback ensure_user_data_created(SessionState.t()) :: :ok | {:error, reason()}
  @callback on_ui_changed(
              SessionState.t(),
              {:ui, ui()} | {:patches, patches()} | {:error, tuple() | String.t()}
            ) :: :ok
end
