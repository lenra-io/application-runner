defmodule ApplicationRunner.Action do
  @moduledoc """
    The Action struct.
  """
  @enforce_keys [:user_id, :app_name]
  defstruct [
    :user_id,
    :app_name,
    :build_number,
    :action_key,
    :action_name,
    :event,
    :action_logs_uuid,
    :old_data,
    :props
  ]

  @type t :: %ApplicationRunner.Action{
          user_id: integer(),
          app_name: String.t(),
          build_number: integer(),
          action_key: String.t(),
          action_name: String.t(),
          event: map(),
          action_logs_uuid: String.t(),
          old_data: map(),
          props: map()
        }
end
