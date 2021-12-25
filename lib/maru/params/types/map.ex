defmodule Maru.Params.Types.Map do
  @moduledoc """
  Buildin Type: Map
  """

  use Maru.Params.Type

  def parse(input, _) when is_map(input), do: {:ok, input}

  def parse(input, _) do
    {:error, :parse, "unknown input format as map: #{inspect(input)}"}
  end
end
