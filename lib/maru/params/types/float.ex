defmodule Maru.Params.Types.Float do
  @moduledoc """
  Buildin Type: Float

  ## Parser Arguments
      * style - float style
        * `:native` (default) - native float
        * `:decimals` - uses `Decimal.new/1` to parse the binary

  ## Examples:
      optional :pi, Float
      optional :pi, Float, style: :decimals
  """

  use Maru.Params.Type

  def parser_arguments, do: [:style]

  def parse(input, args) do
    args
    |> Map.get(:style, :native)
    |> case do
      :native when is_float(input) ->
        {:ok, input}

      :native when is_integer(input) ->
        {:ok, :erlang.float(input)}

      :native when is_binary(input) ->
        {parsed, _} = Elixir.Float.parse(input)
        {:ok, parsed}

      :decimals ->
        {:ok, input |> to_string() |> Decimal.new()}
    end
  rescue
    _ -> {:error, :parse, "unknown format as float: #{inspect(input)}"}
  end
end
