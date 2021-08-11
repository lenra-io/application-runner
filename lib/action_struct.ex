defmodule ApplicationRunner.Action do
  @moduledoc """
    The Action struct.
  """
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
end
