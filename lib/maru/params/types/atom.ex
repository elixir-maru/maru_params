defmodule Maru.Params.Types.Atom do
  @moduledoc """
  Buildin Type: Atom

  ## Validator Arguments
      * `:ecto_enum` - validate input by `Ecto.Enum.dump_values/2`
      * `:values` - validate output is one item of given values

  ## Examples
      optional :role, Atom, values: [:role1, :role2]
      optional :fruit, Atom, ecto_enum: {User, :fruit}
  """

  use Maru.Params.Type

  def parser_arguments, do: [:ecto_enum]

  def validator_arguments, do: [:values]

  def parse(input, _) when is_atom(input), do: {:ok, input}

  def parse(input, %{ecto_enum: {model, field}}) do
    values = apply(Ecto.Enum, :dump_values, [model, field])

    if input in values do
      {:ok, input |> to_string |> String.to_existing_atom()}
    else
      {:error, :validate,
       "Given input `#{input}` not in allowed values: #{Enum.join(values, ", ")}"}
    end
  rescue
    ArgumentError -> {:error, :parse, "not an already existing atom"}
  end

  def parse(input, _) do
    {:ok, input |> to_string |> String.to_existing_atom()}
  rescue
    ArgumentError -> {:error, :parse, "not an already existing atom"}
  end

  def validate(parsed, values: [h | _] = values) when is_atom(h) do
    if parsed in values do
      {:ok, parsed}
    else
      {:error, :validate,
       "Given input `#{parsed}` not in allowed values: #{Enum.join(values, ", ")}"}
    end
  end

  def validate(parsed, values: _values) do
    {:ok, parsed}
  end
end
