defmodule Maru.Params.Runtime do
  defstruct name: nil,
            required: false,
            source: nil,
            nested: nil,
            children: [],
            blank_func: nil,
            parser_func: nil,
            validate_func: nil

  alias Maru.Params.ParseError

  def parse_params(params_runtime, params, options \\ []) do
    parse_params(params_runtime, params, options, %{})
  end

  def parse_params([], _params, _options, result), do: result

  def parse_params([h | t], params, options, result) do
    source =
      case Keyword.get(options, :keys, :strings) do
        :strings -> to_string(h.source)
        _ when is_atom(h.source) -> h.source
        :atoms when is_binary(h.source) -> String.to_atom(h.source)
        :atoms! when is_binary(h.source) -> String.to_existing_atom(h.source)
      end

    passed? = Map.has_key?(params, source)
    value = Map.get(params, source)
    nested = h.nested

    parsed =
      if value in [nil, "", '', %{}] do
        h.blank_func.({value, passed?})
      else
        h.parser_func.({:ok, value})
      end

    case parsed do
      :ignore ->
        parse_params(t, params, options, result)

      {:error, step, reason} ->
        raise Maru.Params.ParseError, attribute: h.name, step: step, reason: reason

      {:ok, value} when nested == :map ->
        value = parse_params(h.children, value, options, %{})
        parse_params(t, params, options, Map.put(result, h.name, value))

      {:ok, value} when nested == :list_of_map ->
        value = Enum.map(value, fn item -> parse_params(h.children, item, options, %{}) end)
        parse_params(t, params, options, Map.put(result, h.name, value))

      {:ok, value} when nested == :list_of_single ->
        value =
          Enum.map(value, fn
            {:ok, item} ->
              item

            {:error, step, reason} ->
              raise ParseError, attribute: h.name, step: step, reason: reason
          end)

        parse_params(t, params, options, Map.put(result, h.name, value))

      {:ok, value} when nested == nil ->
        parse_params(t, params, options, Map.put(result, h.name, value))
    end
  end
end
