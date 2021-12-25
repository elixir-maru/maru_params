defmodule Maru.Params.PhoenixController do
  defmacro __using__(_) do
    quote do
      use Maru.Params.Builder
      Module.register_attribute(__MODULE__, :actions, accumulate: true)
      import unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro params(action, do: block) do
    quote do
      unquote(block)
      @actions {unquote(action), Maru.Params.Builder.pop_params(__ENV__)}
    end
  end

  defmacro __before_compile__(%Macro.Env{module: module}) do
    module
    |> Module.get_attribute(:actions)
    |> Enum.map(fn {action, params} ->
      params_runtime = Enum.map(params, &Map.get(&1, :runtime))

      quote do
        defoverridable [{unquote(action), 2}]

        def unquote(action)(conn, params) do
          super(conn, Maru.Params.Runtime.parse_params(unquote(params_runtime), params))
        end
      end
    end)
  end
end
