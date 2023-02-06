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

  # def load_raw_schema(schema, component_name) do
  #   GenServer.call(__MODULE__, {:load_raw_schema, schema, component_name})
  # end

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  # Server (callbacks)
  @impl true
  def init(_) do
    root_json_directory =
      Application.app_dir(:application_runner, @component_api_directory) <>
        "/component.schema.json"

    {:ok, file_content} = File.read(root_json_directory)

    schemata_map =
      file_content
      |> Jason.decode!()
      |> ExComponentSchema.Schema.resolve()

    schema = load_schema(schemata_map)

    {:ok, %{schemata_map: schemata_map, schema: schema}}
  end

  def load_schema(root_schema) do
    Map.replace(
      root_schema,
      :refs,
      Map.map(root_schema.refs, fn {id, ref} ->
        try do
          ref_properties = ApplicationRunner.SchemaParser.parse(root_schema, ref)
          Map.merge(%{schema: ref}, ref_properties)
        rescue
          e in ExComponentSchema.Schema.InvalidSchemaError ->
            reraise ExComponentSchema.Schema.InvalidSchemaError,
                    [message: "#{id} #{e.message}"],
                    __STACKTRACE__
        end
      end)
    )
  end

  # defp load_raw_schema(schema, schemata_map, component_name) do
  #   resolved_schema = ExComponentSchema.Schema.resolve(schema)

  #   properties = ApplicationRunner.SchemaParser.parse(schema, resolved_schema)

  #   [{get_component_path(component_name), Map.merge(%{schema: resolved_schema}, properties)}]
  #   |> Enum.into(schemata_map)
  # end

  def read_schema(path, root_location) do
    formatted_path =
      if root_location == "component.schema.json" do
        Path.join("/", path)
      else
        String.replace(root_location, ~r/\/.+\.schema\.json/, "/")
        |> Path.join(path)
      end

    "#{Application.app_dir(:application_runner, @component_api_directory)}/#{formatted_path}"
    |> File.read()
    |> case do
      {:ok, file_content} -> file_content
      {:error, _reason} -> raise "Cannot load json schema #{path}"
    end
    |> Jason.decode!()
  end

  def get_component_path(comp_type), do: "components/#{comp_type}.schema.json"

  # @impl true
  # def handle_call({:load_raw_schema, schema, component_name}, _from, schemata_map) do
  #   {:reply, :ok, load_raw_schema(schema, schemata_map, component_name)}
  # end

  @impl true
  def handle_call({:get_schema_map, path}, _from, schemata_map) do
    IO.inspect({:get_schema_map, path})

    res =
      if path == :root do
        Map.get(schemata_map, :schemata_map) |> IO.inspect()
      else
        IO.inspect(Map.get(schemata_map, :schema))

        case Map.fetch(Map.get(schemata_map, :schema).refs, path) |> IO.inspect() do
          :error -> {:error, [{"Invalid component type", "#"}]}
          res -> res
        end
      end

    {:reply, res, schemata_map}
  end
end
