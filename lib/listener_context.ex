defmodule ApplicationRunner.ListenerContext do
  @moduledoc """
    The Listener Context struct that contain every listener informations.
  """
  @enforce_keys [:listener_key]
  defstruct [
    :listener_key,
    :event,
    :data_query,
    :props
  ]

  @type t :: %ApplicationRunner.ListenerContext{
    listener_key: String.t() | nil,
    event: map() | nil,
    data_query: map() | nil,
    props: map() | nil
  }
end
