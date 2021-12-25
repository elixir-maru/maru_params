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

  def parse(input, ecto_enum: {model, field}) do
    values = apply(Ecto.Enum, :dump_values, [model, field])

    if input in values do
      {:ok, input |> to_string |> String.to_existing_atom()}
    else
      {:error, :validate, "allowed values: #{Enum.join(values, ", ")}"}
    end
  end

  def parse(input, _) do
    {:ok, input |> to_string |> String.to_existing_atom()}
  end

  def validate(parsed, values: values) do
    if parsed in values do
      {:ok, parsed}
    else
      {:error, :validate, "allowed values: #{Enum.join(values, ", ")}"}
    end
  end
end
