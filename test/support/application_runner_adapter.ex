defmodule ApplicationRunner.ApplicationRunnerAdapter do
  @moduledoc """
  Fake ApplicationRunnerAdapter for ApplicationRunner
  """
  @behaviour ApplicationRunner.AdapterBehavior

  alias ApplicationRunner.{SessionState, EnvState}

  @root %{
    "type" => "flex",
    "children" => [
      %{"type" => "text", "value" => "foo"},
      %{"type" => "widget", "name" => "w1"},
      %{"type" => "widget", "name" => "w2"}
    ]
  }
  @w1 %{"type" => "text", "value" => "bar"}
  @w2 %{"type" => "button", "text" => "butt", "onPressed" => %{"action" => "inc", "props" => %{}}}

  @manifest %{"widgets" => %{"root" => @root}, "entrypoint" => "root"}

  @impl true
  def get_manifest(_app) do
    {:ok, @manifest}
  end

  @impl true
  def get_widget("root", _data, _props) do
    {:ok, @root}
  end

  def get_widget("w1", data, _) do
    {:ok, Map.put(@w1, "value", "#{data["value"]}")}
  end

  def get_widget("w2", _, _) do
    {:ok, @w2}
  end

  def get_widget(name, _, _) do
    raise "no component #{name}"
  end

  @impl true
  def run_listener(%EnvState{}, "inc", data, _props, _event) do
    {:ok, %{"value" => data["value"] + 1}}
  end

  def run_listener(%EnvState{}, "InitData", _data, _props, _event) do
    {:ok, %{"value" => 0}}
  end

  def run_listener(%EnvState{}, _action, data, _props, _event) do
    {:ok, data}
  end

  @impl true
  def get_data(%SessionState{session_id: session_id} = _session_state) do
    if :ets.whereis(:data) == :undefined do
      :ets.new(:data, [:named_table, :public])
    end

    case :ets.lookup(:data, session_id) do
      [{_, data}] -> {:ok, data}
      [] -> {:ok, %{}}
    end
  end

  @impl true
  def save_data(%SessionState{session_id: session_id} = _session_state, data) do
    if :ets.whereis(:data) == :undefined do
      :ets.new(:data, [:named_table])
    end

    :ets.insert(:data, {session_id, data})
    :ok
  end

  @impl true
  def on_ui_changed(_session_state, ui) do
    IO.inspect(ui)
    :ok
  end
end
