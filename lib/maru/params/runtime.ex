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
    nested = h.nested

    parsed =
      if value in [nil, "", '', %{}] do
        h.blank_func.({value, passed?})
      else
        h.parser_func.({:ok, value})
      end

    case parsed do
      :ignore ->
        parse_params(t, params, result)

      {:error, step, reason} ->
        raise "Params Parse Error: #{step}, #{reason}"

      {:ok, value} when nested == :map ->
        value = parse_params(h.children, value, %{})
        parse_params(t, params, Map.put(result, h.name, value))

      {:ok, value} when nested == :list_of_map ->
        value = Enum.map(value, fn item -> parse_params(h.children, item, %{}) end)
        parse_params(t, params, Map.put(result, h.name, value))

      {:ok, value} when nested == :list_of_single ->
        value =
          Enum.map(value, fn
            {:ok, item} -> item
            {:error, step, reason} -> raise "Params Parse Error: #{step}, #{reason}"
          end)

        parse_params(t, params, Map.put(result, h.name, value))

      {:ok, value} when nested == nil ->
        parse_params(t, params, Map.put(result, h.name, value))
    end
  end
end
