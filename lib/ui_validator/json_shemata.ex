defmodule ApplicationRunner.JsonSchemata do
  use GenServer

  @moduledoc """
    `LenraServers.JsonValidator` is a GenServer that allow to validate a json schema with `LenraServers.JsonValidator.validate_ui/1`
  """

  # Client (api)
  @component_api_directory "priv/components-api/api"

  def get_schema_map(path) do
    GenServer.call(__MODULE__, {:get_schema_map, path})
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  # Server (callbacks)
  @impl true
  def init(_) do
    root_json_directory = Application.app_dir(:application_runner, @component_api_directory)

    relative_shemata_path =
      Path.join(root_json_directory, "/**/*.schema.json")
      |> Path.wildcard()
      |> Enum.map(&Path.relative_to(&1, root_json_directory))

    schemata = Enum.map(relative_shemata_path, &load_schema/1)
    schemata_map = Enum.zip(relative_shemata_path, schemata) |> Enum.into(%{})

    {:ok, schemata_map}
  end

  def load_schema(path) do
    schema =
      read_schema(path)
      |> ExComponentSchema.Schema.resolve()

    schema_properties = ApplicationRunner.SchemaParser.parse(schema)

    Map.merge(%{schema: schema}, schema_properties)
  end

  def read_schema(path) do
    Application.app_dir(:application_runner, @component_api_directory)
    |> Path.join(path)
    |> File.read()
    |> case do
      {:ok, file_content} -> file_content
      {:error, _reason} -> raise "Cannot load json schema #{path}"
    end
    |> Jason.decode!()
  end

  def get_component_path(comp_type), do: "components/#{comp_type}.schema.json"

  @impl true
  def handle_call({:get_schema_map, path}, _from, schemata_map) do
    {:reply, Map.get(schemata_map, path, :error), schemata_map}
  end
end
