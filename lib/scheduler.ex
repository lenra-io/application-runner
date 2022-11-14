defmodule ApplicationRunner.Scheduler do
  @moduledoc false
  use Quantum, otp_app: :application_runner, name: ApplicationRunner.Scheduler
  use SwarmNamed
end
