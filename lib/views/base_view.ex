defmodule ApplicationRunner.BaseView do
  use ApplicationRunner, :view

  def render("success.json", %{data: data}) do
    %{
      "success" => true,
      "data" => data
    }
  end

  def render("success.json", _no_data) do
    %{
      "success" => true
    }
  end

  def render("error.json", %{errors: errors}) do
    %{"errors" => translate_errors(errors), "success" => false}
  end
end
