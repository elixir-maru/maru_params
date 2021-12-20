defmodule Maru.Params.Types.String do
  @moduledoc """
  Examples:
    `optional :id, String, regex: ~r/\d{7,10}/`
    `optional :fruit, Datetime, values: ["apple", "peach"]`
  """

  use Maru.Params.Type

  def validator_arguments, do: [:regex, :values]

  def parse(input, _) when is_binary(input), do: {:ok, input}

  def parse(input, _) do
    {:ok, to_string(input)}
  rescue
    _ -> {:error, :parse, "error parsing string"}
  end

  def validate(parsed, regex: regex) do
    if Regex.match?(regex, parsed) do
      {:ok, parsed}
    else
      {:error, :validate, "regex check error"}
    end
  end

  def validate(parsed, values: values) do
    if parsed in values do
      {:ok, parsed}
    else
      {:error, :validate, "allowed values: #{values}"}
    end
  end
end
