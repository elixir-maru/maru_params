json_library = Application.get_env(:maru_params, :json_library, Jason)

if Code.ensure_loaded?(json_library) do
  defmodule Maru.Params.Types.Json do
    @moduledoc """
    Buildin Type: Json

    ## Parser Arguments
    * `:json_library_options` - options for json library

    ## Examples
    requires :tags, Json |> List[Integer], max_length: 3
    requires :data, Json |> Map do
      optional :nested, String
    end
    """

    use Maru.Params.Type

    def parser_arguments, do: [:json_library_options]

    def parse(input, args) do
      options = Map.get(args, :json_library_options, [])

      input
      |> unquote(json_library).decode(options)
      |> case do
        {:ok, data} -> {:ok, data}
        {:error, error} -> {:error, :parse, error}
      end
    end
  end
end
