defmodule ApplicationRunner.Notifications do
  @doc """
    Put the "to_uids" field from given "Notif" using the "to" field.
  """

  alias ApplicationRunner.Notifications.Notif
  alias ApplicationRunner.MongoStorage

  @spec put_uids_to_notif(Notif.t(), String.t()) :: Notif.t()
  def put_uids_to_notif(%Notif{} = notif, at_me_muid) do
    IO.inspect("put_uids_to_notif")

    to_uids =
      notif.to
      |> Enum.map(fn
        "@me" -> at_me_muid
        muid -> muid
      end)
      |> MongoStorage.muids_to_uids()
      |> IO.inspect()

    Notif.put_to_uids(notif, to_uids) |> IO.inspect()
  end
end
