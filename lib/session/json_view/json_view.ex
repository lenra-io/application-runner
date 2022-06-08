defmodule ApplicationRunner.JsonView do
  alias ApplicationRunner.{
    AdapterHandler,
    DataServices
  }

  @spec get_and_build_ui(SessionState.t(), map()) ::
          {:ok, map()} | {:error, any()}
  def get_and_build_ui(session_state, root_widget) do
    props = Map.get(root_widget, "props")
    name = Map.get(root_widget, "name")
    query = root_widget |> Map.get("query") |> DataServices.json_parser()

    data =
      if is_nil(query) do
        []
      else
        AdapterHandler.exec_query(session_state, query)
      end

    AdapterHandler.get_widget(session_state, name, data, props)
  end
end
