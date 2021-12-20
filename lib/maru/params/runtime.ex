defmodule Maru.Params.Runtime do
  defstruct name: nil,
            required: false,
            source: nil,
            nested: nil,
            children: [],
            blank_func: nil,
            parser_func: nil,
            validate_func: nil

  def parse_params(params_runtime, params) do
    parse_params(params_runtime, params, %{})
  end

  def parse_params([], _params, result), do: result

  def parse_params([h | t], params, result) do
    passed? = Map.has_key?(params, h.source)
    value = Map.get(params, h.source)

    parsed =
      if value in [nil, "", '', %{}] do
        h.blank_func.({value, passed?})
      else
        h.parser_func.({:ok, value})
      end

    case parsed do
      {:ok, value} -> parse_params(t, params, Map.put(result, h.name, value))
      :ignore -> parse_params(t, params, result)
      {:error, step, reason} -> raise "Params Parse Error: #{step}, #{reason}"
    end
  end
end
