defmodule ApplicationRunner.Notifications do
  @doc """
    Put the "to_uids" field from given "Notif" using the "to" field.
  """

  alias ApplicationRunner.Notifications.Notif
  alias ApplicationRunner.MongoStorage

  @spec put_uids_to_notif(Notif.t()) :: Notif.t()
  def put_uids_to_notif(%Notif{} = notif) do
    to_uids = MongoStorage.muids_to_uids(notif.to)
    Notif.put_to_uids(notif, to_uids)
  end
end
