defmodule ApplicationRunner.AppContext do
  @moduledoc """
    The Action struct.
  """
  @enforce_keys [:user_id, :app_name, :build_number]
  defstruct [
    :user_id,
    :app_name,
    :build_number,
    :action_logs_uuid,
    :widgets_map
  ]

  @type t :: %ApplicationRunner.AppContext{
    user_id: integer(),
    app_name: String.t(),
    build_number: integer(),
    action_logs_uuid: String.t() | nil,
    widgets_map: map()
  }
end
