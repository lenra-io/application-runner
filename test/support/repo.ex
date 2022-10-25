defmodule ApplicationRunner.Repo do
  use Ecto.Repo, otp_app: :lenra, adapter: Ecto.Adapters.Postgres
end
