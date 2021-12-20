defmodule Maru.Params.PhoenixController do
  defmacro __using__(_) do
    quote do
      use Maru.Params.Builder
      import unquote(__MODULE__)
    end
  end

  defmacro params(action, do: block) do
    quote do
      unquote(block)
      @actions {unquote(action), Maru.Params.Builder.pop_params(__ENV__)}
    end
  end
end
