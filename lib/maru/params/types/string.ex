defmodule Maru.Params.Types.String do
  @moduledoc """
  Buildin Type: String

  ## Parser Arguments
      * `:style` - string style
        * `:upcase`
        * `:downcase`
        * `:camelcase`
        * `:snakecase`

  ## Validator Arguments
      * `:regex` - validate input by regex
      * `:values` - validate input is one item of given values

  ## Examples
    optional :id, String, regex: ~r/\d{7,10}/
    optional :fruit, String, values: ["apple", "peach"]
    optional :code, String, style: :upcase
  """

  use Maru.Params.Type

  def parser_arguments, do: [:style]

  def validator_arguments, do: [:regex, :values]

  def parse(input, args) do
    input = to_string(input)

    args
    |> Map.get(:style)
    |> case do
      nil -> input
      :upcase -> String.upcase(input)
      :downcase -> String.downcase(input)
      :snakecase -> Macro.underscore(input)
      :camelcase -> Macro.camelize(input)
    end
    |> then(&{:ok, &1})
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
