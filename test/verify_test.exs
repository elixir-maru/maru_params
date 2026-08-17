defmodule Maru.Params.VerifyTest do
  use ExUnit.Case, async: true

  defmodule MissingReads do
    use Maru.Params.TestHelper

    params :t do
      requires :contents, List do
        # `Test.Schema.AddressWidget` reads `:subtype`, which nothing declares here
        optional :label, String
        include Test.Schema.AddressWidget
      end
    end
  end

  defmodule UnknownBlock do
    use Maru.Params.TestHelper

    params :t do
      include Test.Schema.Pair, only: [:first, :nope]
    end

    params :ok do
      include Test.Schema.Pair, only: :first
    end
  end

  defmodule NotASchema do
    use Maru.Params.TestHelper

    params :t do
      include Enum
    end
  end

  defmodule Impostor do
    # exports __maru_params__/0 but is not a schema
    def __maru_params__, do: [:default]
  end

  defmodule IncludesImpostor do
    use Maru.Params.TestHelper

    params :t do
      include Maru.Params.VerifyTest.Impostor
    end
  end

  defmodule Ok do
    use Maru.Params.TestHelper

    params :t do
      requires :contents, List do
        requires :subtype, Atom
        include Test.Schema.AddressWidget
        include Test.Schema.MotivationWidget
      end
    end
  end

  test "verify_modules/1 catches a missing reads: name" do
    error =
      assert_raise RuntimeError, fn ->
        Maru.Params.verify_modules([MissingReads])
      end

    assert error.message =~ "Maru.Params.VerifyTest.MissingReads params :t at `contents`"

    assert error.message =~
             "included Test.Schema.AddressWidget reads [:subtype] which is not declared"
  end

  test "verify_modules/1 catches an unknown only: block" do
    error =
      assert_raise RuntimeError, fn ->
        Maru.Params.verify_modules([UnknownBlock])
      end

    assert error.message =~ "Maru.Params.VerifyTest.UnknownBlock params :t:"
    assert error.message =~ "params block [:nope] not found in Test.Schema.Pair"
    refute error.message =~ "params :ok"
  end

  test "verify_modules/1 catches an include of a module which isn't a schema" do
    assert_raise RuntimeError, ~r/included Enum is not a Maru.Params.Schema/, fn ->
      Maru.Params.verify_modules([NotASchema])
    end

    assert_raise RuntimeError, ~r/included .*Impostor is not a Maru.Params.Schema/, fn ->
      Maru.Params.verify_modules([IncludesImpostor])
    end
  end

  test "verify_modules/1 reports every problem at once" do
    error =
      assert_raise RuntimeError, fn ->
        Maru.Params.verify_modules([MissingReads, UnknownBlock, NotASchema])
      end

    assert 3 == (error.message |> String.split("\n  * ") |> length()) - 1
  end

  test "verify_modules/1 passes on a correct module" do
    assert :ok == Maru.Params.verify_modules([Ok])
  end

  test "verify_modules/1 ignores modules without params blocks" do
    assert :ok == Maru.Params.verify_modules([Enum, NotEvenAModule])
  end

  test "verify_all/1 walks every module of an application" do
    assert :ok == Maru.Params.verify_all([:maru_params])
    assert :ok == Maru.Params.verify_all(:maru_params)

    assert Test.Schema.AddressWidget in Application.spec(:maru_params, :modules)
  end

  test "verify_all/1 of an unknown application raises" do
    assert_raise ArgumentError, ~r/application :no_such_app is not loaded/, fn ->
      Maru.Params.verify_all([:no_such_app])
    end
  end
end
