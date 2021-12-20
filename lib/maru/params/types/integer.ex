defmodule Maru.Params.Types.Integer do
  @moduledoc """
  Examples:
    `optional :id, Integer`
  """

  use Maru.Params.Type

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
    input |> IO.inspect()
    {:error, :parse, "unknown input format"}
  end
end
