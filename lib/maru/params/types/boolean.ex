defmodule Maru.Params.Types.Boolean do
  @moduledoc """
  Buildin Type: Boolean

  ## Examples
      optional :save, Boolean
  """

  use Maru.Params.Type

  @doc false
  def parse(true, _), do: {:ok, true}
  def parse("true", _), do: {:ok, true}
  def parse(nil, _), do: {:ok, false}
  def parse(false, _), do: {:ok, false}
  def parse("false", _), do: {:ok, false}
  def parse(input, _), do: {:error, :parse, "unknown boolean format: #{inspect(input)}"}
end
