defmodule ApplicationRunner.AdapterBehavior do
  @moduledoc """
  ApplicationRunner's AdapterBehavior
  """
  alias ApplicationRunner.{
    EnvState,
    SessionState
  }

  alias QueryParser.AST

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

  @callback get_env_and_fucntion_name(Integer.t()) :: {:ok, map()} | {:error, reason()}

  @callback on_ui_changed(
              SessionState.t(),
              {:ui, ui()} | {:patches, patches()} | {:error, tuple() | String.t()}
            ) :: :ok
end
