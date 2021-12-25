if Code.ensure_loaded?(Plug) do
  defmodule Maru.Params.Types.File do
    @moduledoc """
    Buildin Type: File
    """

    use Maru.Params.Type

    def parse(%Plug.Upload{} = input, _), do: {:ok, input}
    def parse(input, _), do: {:error, :parse, "unknown format as file: #{inspect(input)}"}
  end
end
