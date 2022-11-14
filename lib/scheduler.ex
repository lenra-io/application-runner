defmodule ApplicationRunner.Scheduler do
  @moduledoc false
  use Quantum, otp_app: :application_runner
  use SwarmNamed
end
