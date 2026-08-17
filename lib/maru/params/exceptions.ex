defmodule Maru.Params.TypeError do
  defexception [:type, :reason]

  def message(%{type: type, reason: reason}) do
    "Type #{type} Error: #{reason}"
  end
end

defmodule Maru.Params.ParseError do
  @moduledoc """
  Raised when a parameter can't be parsed or validated.

  `:attribute` is the name of the parameter itself while `:path` is the
  full position of it within the parsed params, for example
  `[:address, :tags, 0]` for the first element of `address.tags`.
  """

  defexception [:attribute, :step, :reason, path: []]

  def message(%{step: :parse} = e) do
    "Error Parsing Parameter `#{position(e)}`: #{e.reason}"
  end

  def message(%{step: :validate} = e) do
    "Error Validating Parameter `#{position(e)}`: #{e.reason}"
  end

  @doc """
  Human readable position of the parameter which caused the error,
  e.g. `address.tags[0]`.
  """
  def position(%{path: path, attribute: attribute}) do
    case path do
      p when p in [nil, []] -> to_string(attribute)
      [h | t] -> do_position(t, to_string(h))
    end
  end

  defp do_position([], acc), do: acc
  defp do_position([h | t], acc) when is_integer(h), do: do_position(t, "#{acc}[#{h}]")
  defp do_position([h | t], acc), do: do_position(t, "#{acc}.#{h}")
end
