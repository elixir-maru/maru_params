defmodule Maru.Params.Types.Base64 do
  @moduledoc """
  Buildin Type: Base64

  ## Parser Arguments
      * `:options` - options for `Base.decode64/2`

  ## Examples
      requires :data, Base64, options: [padding: false]
  """

  use Maru.Params.Type

  def parser_arguments, do: [:options]

  def parse(input, args) do
    options = Map.get(args, :options, [])

    case Base.decode64(input, options) do
      {:ok, data} -> {:ok, data}
      :error -> {:error, :parse, "error parsing base64"}
    end
  end
end
