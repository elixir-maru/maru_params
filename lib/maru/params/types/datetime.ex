defmodule Maru.Params.Types.DateTime do
  @moduledoc """
  Example: `optional :date, Datetime, format: "iso8601"`
  """

  use Maru.Params.Type

  def parser_arguments, do: [:format, :naive, :truncate]

  def parse(input, %{format: "iso8601"}=args) do
    module = if Map.get(args, :naive), do: NaiveDateTime, else: DateTime

    case module.from_iso8601(input) do
      {:ok, datetime, _} ->
        case Map.get(args, :truncate) do
          nil -> {:ok, datetime}
          unit -> {:ok, module.truncate(datetime, unit)}
        end
      _ ->
        {:error, :parse, "invalid iso8601 format"}
    end
  end

  def parse(_input, %{format: format}) do
    {:error, :parse, "unsupported format #{format}"}
  end
end
