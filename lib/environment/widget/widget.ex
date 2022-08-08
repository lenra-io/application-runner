defmodule ApplicationRunner.Environment.Widget do
  use GenServer

  alias ApplicationRunner.{ApplicationServices, Session, Widget}

  def init(%Session.State{} = session_state, %Widget.Context{} = current_widget) do
    case ApplicationServices.fetch_widget(
           session_state,
           current_widget.name,
           current_widget.data,
           current_widget.props
         ) do
      {:ok, widget} ->
        nil

      {:error, error} ->
        raise error
    end
  end
end
