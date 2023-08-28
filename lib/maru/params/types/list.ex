defmodule Maru.Params.Types.List do
  @moduledoc """
  Buildin Type: List

  ## Parser Arguments
      * `:unique` - whether unique the data in list with `Enum.uniq`
        * `true` - unique the list
        * `false` (default) - do NOT unique the list
      * `:string_strategy` - how to parse a string value
        * `:codepoints` (default) - decode by `String.codepoints/1`
        * `:charlist` - decode by `String.to_charlist/1`
        * `:wrap` - decode by `List.wrap/1`

  ## Validator Arguments
      * `:max_length` - max length of the list
      * `:min_length` - min length of the list
      * `:length_range` - length range of the list

  ## Examples:
      requires :tags, List[String], max_length: 3
      requires :chars, List, string_strategy: :charlist
  """

  use Maru.Params.Type

  def parser_arguments, do: [:string_strategy, :unique]

  def validator_arguments, do: [:min_length, :max_length, :length_range]

  def parse(input, args) when is_list(input) do
    args
    |> Map.get(:unique, false)
    |> case do
      true -> {:ok, Enum.uniq(input)}
      false -> {:ok, input}
    end
  end

  def parse(input, args) when is_binary(input) do
    args
    |> Map.get(:string_strategy, :codepoints)
    |> case do
      :codepoints -> String.codepoints(input)
      :charlist -> String.to_charlist(input)
      :wrap -> List.wrap(input)
    end
    |> parse(args)
  end

  def parse(input, _) do
    {:error, :parse, "unknown input format, expected List, got: #{inspect(input)}"}
  end

  def validate(parsed, min_length: min_length) do
    if length(parsed) >= min_length do
      {:ok, parsed}
    else
      {:error, :validate, "min length: #{min_length}"}
    end
  end

  def validate(parsed, max_length: max_length) do
    if length(parsed) <= max_length do
      {:ok, parsed}
    else
      {:error, :validate, "max length: #{max_length}"}
    end
  end

  def validate(parsed, length_range: %Range{first: min_length, last: max_length}) do
    len = length(parsed)

    if len >= min_length and len <= max_length do
      {:ok, parsed}
    else
      {:error, :validate, "length range: #{min_length}..#{max_length}"}
    end
  end
end
