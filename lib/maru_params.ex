require Logger

defmodule MaruParams do
  json_library = Application.get_env(:maru_params, :json_library, Jason)

  unless Code.ensure_loaded?(json_library) do
    Logger.warn(
      "Json library #{json_library} is not loaded, add your json library to deps and config with `config :maru_params, :json_library, #{json_library}`"
    )
  end

  def json_library do
    unquote(json_library)
  end
end
