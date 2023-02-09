defmodule ApplicationRunner.Environment.Metadata do
  @moduledoc """
    The Environmnet metadata.
  """
  @enforce_keys [:env_id, :function_name, :token]
  defstruct [
    :env_id,
    :function_name,
    :token
  ]

  @type t :: %__MODULE__{
          env_id: term(),
          function_name: term(),
          token: term()
        }
end
