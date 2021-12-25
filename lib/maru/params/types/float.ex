defmodule Maru.Params.Types.Float do
  @moduledoc """
  Buildin Type: Float

  ## Examples:
      optional :pi, Float
  """

  use Maru.Params.Type

  @doc false
  def parse(input, _) when is_float(input), do: {:ok, input}
  def parse(input, _) when is_integer(input), do: {:ok, :erlang.float(input)}

  def parse(input, _) when is_binary(input) do
    case Elixir.Float.parse(input) do
      {parsed, _} -> {:ok, parsed}
      :error -> {:error, :parse, "unable to parse float from string: #{input}"}
    end
  end

  def parse(input, _), do: {:error, :parse, "unknown format as float: #{inspect(input)}"}
end
