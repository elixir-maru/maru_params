defmodule Maru.Params.Types.Integer do
  @moduledoc """
  Buildin Type: Integer

  ## Examples
      optional :age, Integer
  """

  use Maru.Params.Type

  def validator_arguments, do: [:min, :max, :range]

  def parse(input, _) when is_integer(input), do: {:ok, input}

  def parse(input, options) when is_list(input) do
    input |> to_string() |> parse(options)
  end

  def parse(input, _) when is_binary(input) do
    case Integer.parse(input) do
      {int, ""} -> {:ok, int}
      _ -> {:error, :parse, "error prasing #{input} as integer"}
    end
  end

  def parse(input, _) do
    {:error, :parse, "unknown input format as integer: #{inspect(input)}"}
  end

  def validate(parsed, min: min) do
    if parsed >= min do
      {:ok, parsed}
    else
      {:error, :validate, "min: #{min}"}
    end
  end

  def validate(parsed, max: max) do
    if parsed <= max do
      {:ok, parsed}
    else
      {:error, :validate, "max: #{max}"}
    end
  end

  def validate(parsed, range: %Range{first: min, last: max}) do
    if parsed >= min and parsed <= max do
      {:ok, parsed}
    else
      {:error, :validate, "range: #{min}..#{max}"}
    end
  end
end
