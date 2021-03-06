defmodule Maru.Params.Types.DateTime do
  @moduledoc """
  Buildin Type: DateTime

  ## Parser Arguments
      * `:format` - how to parse a datetime value
        * `:iso8601` - parse by `DateTime.from_iso8601/2` or `NaiveDateTime.from_iso8601/2`
        * `{:unix, unit}` - parse by `DateTime.from_unix/2`
        * `:unix - parse by `DateTime.from_unix/1`
          * `:unit` - unit for unix datetime
            * `:second` (default)
            * `:millisecond`
            * `:microsecond`
            * `:nanosecond`
      * `:naive` - return `DateTime` or `NaiveDateTime` struct
        * `false` (default) - return `DateTime` struct
        * `true` - return `NaiveDateTime` struct
      * `:truncate` - unit to truncate the output
        * `:microsecond`
        * `:millisecond`
        * `:second`

  ## Examples:
      requires :created, DateTime, format: :iso8601, naive: true
      optional :updated, DateTime, format: {:unix, :second}, truncate: :second
  """

  use Maru.Params.Type

  def parser_arguments, do: [:format, :naive, :truncate, :time_zone]

  def parse(input, args) do
    format = Map.get(args, :format)
    naive = Map.get(args, :naive, false)
    unit = Map.get(args, :truncate)

    format
    |> case do
      :iso8601 when naive -> NaiveDateTime.from_iso8601(input)
      :iso8601 -> DateTime.from_iso8601(input)
      :unix -> input |> DateTime.from_unix()
      {:unix, unix_unit} -> DateTime.from_unix(input, unix_unit)
      _ when is_struct(input, DateTime) -> {:ok, input}
      _ when is_struct(input, NaiveDateTime) -> {:ok, input}
      _ -> {:error, "unsupported format"}
    end
    |> case do
      {:ok, %DateTime{} = datetime, _} when naive -> {:ok, DateTime.to_naive(datetime)}
      {:ok, %DateTime{} = datetime, _} -> {:ok, datetime}
      {:ok, %DateTime{} = datetime} when naive -> {:ok, DateTime.to_naive(datetime)}
      {:ok, %DateTime{} = datetime} -> {:ok, datetime}
      {:ok, %NaiveDateTime{}} when not naive -> {:error, "unknown naive timezone"}
      {:ok, %NaiveDateTime{} = datetime} -> {:ok, datetime}
      {:error, reason} -> {:error, reason}
    end
    |> case do
      {:ok, datetime} when is_nil(unit) -> {:ok, datetime}
      {:ok, %DateTime{} = t} -> {:ok, DateTime.truncate(t, unit)}
      {:ok, %NaiveDateTime{} = t} -> {:ok, NaiveDateTime.truncate(t, unit)}
      {:error, reason} -> {:error, :parse, "#{inspect(reason)}: #{inspect(format)}"}
    end
  end
end
