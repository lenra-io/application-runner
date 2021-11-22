defmodule ApplicationRunner.AppLoaderAdapter do
  @moduledoc """
    This module is an adapter that specify the functions needed when loading an app in the tree.
  """

  @doc """
    This function must load the app state/metadata with the given app_id.
    The app_state contain a bunch of metadata needed for the app to load.
  """
  @callback load_app_state(number()) :: {:ok, term()} | {:error, atom()}
end
