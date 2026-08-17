defmodule Maru.Params.CompileDependencyTest do
  @moduledoc """
  `include` must never touch the referenced module at compile time: that is the
  whole point of the design, so it is measured here instead of inferred.

  A remote reference within a module body is a compile time dependency and one
  within a function body is a runtime dependency, and the compiler tells the two
  apart by whether `env.function` is set when it emits `:alias_reference`.

  The same fact is visible from the outside with

      MIX_ENV=test mix xref graph --label compile --sink test/support/schemas.ex
  """

  # the compiler options are global
  use ExUnit.Case, async: false

  @tracer_name :maru_params_compile_tracer

  defmodule Tracer do
    @moduledoc false

    def trace({:alias_reference, _meta, module}, %{function: nil}) do
      send(:maru_params_compile_tracer, {:compile_time_reference, module})
      :ok
    end

    def trace(_event, _env), do: :ok
  end

  setup do
    Process.register(self(), @tracer_name)
    tracers = Code.get_compiler_option(:tracers)
    Code.put_compiler_option(:tracers, [Tracer | tracers])

    on_exit(fn -> Code.put_compiler_option(:tracers, tracers) end)

    :ok
  end

  test "include doesn't reference the included module at compile time" do
    compile("""
    defmodule Maru.Params.CompileDependencyTest.Includer do
      use Maru.Params.Schema

      alias Test.Schema

      params do
        include Schema.Pair
      end

      params :second do
        include Test.Schema.Status, only: :basic
      end
    end
    """)

    refute_receive {:compile_time_reference, Test.Schema.Pair}
    refute_receive {:compile_time_reference, Test.Schema.Status}

    params =
      apply(Maru.Params.CompileDependencyTest.Includer, :__maru_params__, [:default])

    assert [:x, :y] == Enum.map(params, & &1.name)
  end

  test "an alias used only by include still counts as used" do
    {_result, output} =
      ExUnit.CaptureIO.with_io(:stderr, fn ->
        compile("""
        defmodule Maru.Params.CompileDependencyTest.AliasOnly do
          use Maru.Params.Schema

          alias Test.Schema

          params do
            include Schema.Pair
          end
        end
        """)
      end)

    refute output =~ "unused alias"
  end

  test "a custom type is a compile time dependency, unlike a schema" do
    compile("""
    defmodule Maru.Params.CompileDependencyTest.TypeUser do
      use Maru.Params.Schema

      params do
        optional :p, Test.PlainType
      end
    end
    """)

    assert_receive {:compile_time_reference, Test.PlainType}
  end

  defp compile(string) do
    Code.compile_string(string)
  end
end
