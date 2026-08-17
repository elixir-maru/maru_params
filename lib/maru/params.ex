defmodule Maru.Params do
  @moduledoc """
  Runtime verification of `include`.

  `include` never touches the included module at compile time, so nothing about
  it can be checked while compiling. `verify_all/1` runs those checks at
  runtime instead, call it from `Application.start/2` or from a test:

      Maru.Params.verify_all([:my_app])

  For every params block of every module of those applications it asserts that
  every included module is a `Maru.Params.Schema`, that the block names given
  to `:only` / `:except` exist, and that every name of the included module's
  `reads:` is declared before the include at the same level.
  """

  @doc """
  Verify every `include` of every module of the given applications.

  Returns `:ok` or raises with all found problems.
  """
  def verify_all(apps) do
    apps
    |> List.wrap()
    |> Enum.flat_map(&app_modules/1)
    |> verify_modules()
  end

  @doc """
  Verify every `include` of the given modules, see `verify_all/1`.

  Modules without params blocks are ignored.
  """
  def verify_modules(modules) do
    errors =
      for module <- List.wrap(modules),
          Code.ensure_loaded?(module),
          function_exported?(module, :__maru_includes__, 0),
          block <- module.__maru_includes__(),
          include <- module.__maru_includes__(block),
          error <- verify_include(module, block, include) do
        error
      end

    case errors do
      [] ->
        :ok

      errors ->
        raise "maru_params verification failed:\n" <>
                Enum.map_join(errors, "\n", &("  * " <> &1))
    end
  end

  defp app_modules(app) do
    Application.load(app)

    case :application.get_key(app, :modules) do
      {:ok, modules} -> modules
      :undefined -> raise ArgumentError, "application #{inspect(app)} is not loaded"
    end
  end

  defp verify_include(module, block, %{
         module: target,
         opts: opts,
         preceding: preceding,
         path: path
       }) do
    where =
      case path do
        [] -> "#{inspect(module)} params #{inspect(block)}"
        path -> "#{inspect(module)} params #{inspect(block)} at `#{Enum.join(path, ".")}`"
      end

    if Code.ensure_loaded?(target) and function_exported?(target, :__maru_params__, 0) and
         function_exported?(target, :__maru_reads__, 0) do
      block_errors =
        case List.wrap(opts[:only] || opts[:except] || []) -- target.__maru_params__() do
          [] ->
            []

          missing ->
            ["#{where}: params block #{inspect(missing)} not found in #{inspect(target)}"]
        end

      reads_errors =
        case target.__maru_reads__() -- preceding do
          [] ->
            []

          missing ->
            [
              "#{where}: included #{inspect(target)} reads #{inspect(missing)} " <>
                "which is not declared before the include at the same level"
            ]
        end

      block_errors ++ reads_errors
    else
      ["#{where}: included #{inspect(target)} is not a Maru.Params.Schema"]
    end
  end
end
