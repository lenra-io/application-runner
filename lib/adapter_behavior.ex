defmodule ApplicationRunner.AdapterBehavior do
  @moduledoc """
  ApplicationRunner's AdapterBehavior
  """
  alias ApplicationRunner.{EnvState, SessionState}

  @type widget() :: map()
  @type manifest() :: map()
  @type data() :: map()
  @type props() :: map()
  @type event() :: map()
  @type reason() :: atom()
  @type ui() :: map()
  @type patches() :: list(map())
  @type code() :: String.t()
  @type action() :: String.t()
  @type widget_name() :: String.t()

  @callback get_manifest(EnvState.t()) :: {:ok, manifest()} | {:error, reason()}
  @callback get_widget(EnvState.t(), widget_name(), data(), props()) ::
              {:ok, widget()} | {:error, reason()}
  @callback run_listener(EnvState.t(), action(), data(), props(), event()) ::
              {:ok, data()} | {:error, reason()}
  @callback get_data(SessionState.t()) :: {:ok, data()} | {:error, reason()}
  @callback save_data(SessionState.t(), data()) :: :ok | {:error, reason()}
  @callback on_ui_changed(
              SessionState.t(),
              {:ui, ui()} | {:patches, patches()} | {:error, tuple() | String.t()}
            ) :: :ok
end
