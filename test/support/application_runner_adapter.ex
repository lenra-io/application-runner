defmodule ApplicationRunner.ApplicationRunnerAdapter do
  @moduledoc """
  Fake ApplicationRunnerAdapter for ApplicationRunner
  """
  @behaviour ApplicationRunner.AdapterBehavior

  alias ApplicationRunner.{EnvState}

  @root %{
    "type" => "flex",
    "children" => [
      %{"type" => "text", "value" => "foo"},
      %{"type" => "widget", "name" => "w1"},
      %{"type" => "widget", "name" => "w2"}
    ]
  }
  @w1 %{"type" => "text", "value" => "bar"}
  @w2 %{"type" => "button", "text" => "butt", "onPressed" => %{"action" => "act", "props" => %{}}}

  @manifest %{"widgets" => %{"root" => @root}, "entrypoint" => "root"}

  @impl true
  def get_manifest(_app) do
    {:ok, @manifest}
  end

  @impl true
  def get_widget("root", _data, _props) do
    {:ok, @root}
  end

  def get_widget("w1", _, _) do
    {:ok, @w1}
  end

  def get_widget("w2", _, _) do
    {:ok, @w2}
  end

  def get_widget(name, _, _) do
    raise "no component #{name}"
  end

  @impl true
  def run_listener(_app, _listener, _data) do
    {:ok, %{}}
  end

  @impl true
  def get_data(%EnvState{} = _env_state) do
    {:ok, %{"value" => "bar"}}
  end

  @impl true
  def save_data(%EnvState{} = _env_state, _data) do
    :ok
  end

  @impl true
  def on_ui_changed(ui) do
    IO.inspect(ui)
    :ok
  end
end
