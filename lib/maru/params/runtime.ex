defmodule Maru.Params.Runtime do
  defstruct name: nil,
            required: false,
            source: nil,
            nested: nil,
            children: [],
            ignore_func: nil,
            blank_func: nil,
            parser_func: nil

  alias Maru.Params.ParseError

  def parse_params(params_runtime, params, options \\ []) do
    parse_params(params_runtime, params, options, %{})
  end

  def parse_params(params_runtime, params, options, result) do
    do_parse_params(params_runtime, params, options, result, [])
  end

  @doc """
  Run `func` and prepend `prefix` (a path segment or a list of them) to the path
  of the `Maru.Params.ParseError` raised within it, so that the error keeps track
  of its position within the whole params.
  """
  def with_path(prefix, func) do
    func.()
  rescue
    e in ParseError ->
      reraise %{e | path: List.wrap(prefix) ++ (e.path || [])}, __STACKTRACE__
  end

  defp do_parse_params([], _params, _options, result, _path), do: result

  defp do_parse_params([h | t], params, options, result, path) do
    if h.ignore_func.(result) do
      throw(:ignore)
    end

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
    current_path = path ++ [h.name]

    parsed =
      if value in [nil, "", ~c"", %{}] do
        h.blank_func.({value, passed?})
      else
        with_path(current_path, fn -> h.parser_func.({:ok, value}, options) end)
      end

    case parsed do
      :ignore ->
        do_parse_params(t, params, options, result, path)

      {:error, step, reason} ->
        raise ParseError, attribute: h.name, path: current_path, step: step, reason: reason

      {:default, value} ->
        do_parse_params(t, params, options, Map.put(result, h.name, value), path)

      {:ok, value} when nested == :map ->
        value = do_parse_params(h.children, value, options, %{}, current_path)
        do_parse_params(t, params, options, Map.put(result, h.name, value), path)

      {:ok, value} when nested == :list_of_map ->
        value =
          value
          |> Enum.with_index()
          |> Enum.map(fn {item, index} ->
            do_parse_params(h.children, item, options, %{}, current_path ++ [index])
          end)

        do_parse_params(t, params, options, Map.put(result, h.name, value), path)

      {:ok, value} when nested == :list_of_single ->
        value =
          value
          |> Enum.with_index()
          |> Enum.map(fn
            {{:ok, item}, _index} ->
              item

            {{:error, step, reason}, index} ->
              raise ParseError,
                attribute: h.name,
                path: current_path ++ [index],
                step: step,
                reason: reason
          end)

        do_parse_params(t, params, options, Map.put(result, h.name, value), path)

      {:ok, value} when nested == nil ->
        do_parse_params(t, params, options, Map.put(result, h.name, value), path)
    end
  catch
    :ignore -> do_parse_params(t, params, options, result, path)
  end
end
