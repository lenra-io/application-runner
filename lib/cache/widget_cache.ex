defmodule ApplicationRunner.WidgetCache do
  use ApplicationRunner.CacheAsyncMacro

  def get_widget(pid, name, data, props) do
    call_function(pid, ApplicationRunner.ActionBuilder, :get_widget, [name, data, props])
  end
end
