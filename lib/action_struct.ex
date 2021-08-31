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
          action_key: String.t() | nil,
          action_name: String.t() | nil,
          event: map() | nil,
          action_logs_uuid: String.t() | nil,
          old_data: map() | nil,
          props: map() | nil
        }
end
