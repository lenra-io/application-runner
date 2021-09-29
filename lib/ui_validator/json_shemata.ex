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

  def load_raw_schema(schema, component_name) do
    GenServer.call(__MODULE__, {:load_raw_schema, schema, component_name})
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
    try do
      schema =
        read_schema(path)
        |> ExComponentSchema.Schema.resolve()

      schema_properties = ApplicationRunner.SchemaParser.parse(schema)

      Map.merge(%{schema: schema}, schema_properties)
    rescue
      e in ExComponentSchema.Schema.InvalidSchemaError -> raise ExComponentSchema.Schema.InvalidSchemaError, message: "#{path} #{e.message}"
    end
  end

  defp load_raw_schema(schema, schemata_map, component_name) do
    resolved_schema = ExComponentSchema.Schema.resolve(schema)

    properties = ApplicationRunner.SchemaParser.parse(resolved_schema)

    [{get_component_path(component_name), Map.merge(%{schema: resolved_schema}, properties)}]
    |> Enum.into(schemata_map)
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
  def handle_call({:load_raw_schema, schema, component_name}, _from, schemata_map) do
    {:reply, :ok, load_raw_schema(schema, schemata_map, component_name)}
  end

  @impl true
  def handle_call({:get_schema_map, path}, _from, schemata_map) do
    schema_map =
      case Map.fetch(schemata_map, path) do
        :error -> {:error, [{"Invalid component type", "#"}]}
        res -> res
      end

    {:reply, schema_map, schemata_map}
  end
end
