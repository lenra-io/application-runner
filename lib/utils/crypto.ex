defmodule Crypto do
  @moduledoc """
    Crypto is a utility module for all crypto related utilities
  """
  def hash(tuple) do
    :crypto.hash(:sha256, :erlang.term_to_binary({"truc", tuple}))
    |> Base.encode64()
  end
end
