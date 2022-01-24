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

  def validate(parsed, regex: regex_alias) when is_atom(regex_alias) do
    :maru_params
    |> Application.get_env(:regex_aliases, [])
    |> Keyword.get(regex_alias)
    |> case do
      nil -> {:error, :parse, "undefined regex alias: #{regex_alias}"}
      regex -> validate(parsed, regex: regex)
    end
  end

  def validate(parsed, regex: regex) do
    case Regex.match?(regex, parsed) do
      true -> {:ok, parsed}
      false -> {:error, :validate, "regex check error"}
    end
  end

  def validate(parsed, values: [h | _] = values) when is_binary(h) do
    if parsed in values do
      {:ok, parsed}
    else
      {:error, :validate, "allowed values: #{inspect(values)}"}
    end
  end

  def validate(parsed, values: _values) do
    {:ok, parsed}
  end
end
