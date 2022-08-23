defmodule SwarmNamed do
  defmacro __using__(_opts) do
    quote do
      def get_name(identifier) do
        {__MODULE__, identifier}
      end

      def get_full_name(identifier) do
        {:via, :swarm, get_name(identifier)}
      end
    end
  end
end
