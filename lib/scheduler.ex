defmodule ApplicationRunner.Scheduler do
  @moduledoc false
  use Quantum, otp_app: :application_runner

  require Logger

  def init(opts) do
    # TODO START ALL CRONS IN DATABASE HERE
    IO.inspect("INIT SCHEDULER")
    opts
  end
end
