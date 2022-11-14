defmodule Repo do
  @moduledoc false
  use Ecto.Repo,
    otp_app: :application_runner,
    adapter: Ecto.Adapters.Postgres
end
