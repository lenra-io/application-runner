# defmodule ApplicationRunner.AdapterBehavior do
#   @moduledoc """
#   ApplicationRunner's AdapterBehavior
#   """

#   alias ApplicationRunner.SessionState

#   @type widget() :: map()
#   @type manifest() :: map()
#   @type data() :: list(map()) | map()
#   @type props() :: map()
#   @type event() :: map()
#   @type reason() :: atom()
#   @type ui() :: map()
#   @type patches() :: list(map())
#   @type action() :: String.t()
#   @type widget_name() :: String.t()

#   @callback get_env_and_function_name(number()) :: {:ok, map()} | {:error, reason()}

#   # @callback(allow_user_for_app(user, application),
#   #   to: Application.compile_env!(:application_runner, :adapter)
#   # )
# end
