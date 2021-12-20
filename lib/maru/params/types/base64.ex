defmodule Maru.Params.Types.Base64 do
  @moduledoc """
  Example: `optional :date, Base64`
  """

  use Maru.Params.Type

  def parse(input, _) do
    case Base.decode64(input) do
      {:ok, data} -> {:ok, data}
      :error -> {:error, :parse, "error to parse base64"}
    end
  end
end
