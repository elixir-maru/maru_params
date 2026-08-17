defmodule Maru.Params.SchemaTest do
  use ExUnit.Case, async: true

  alias Maru.Params.Schema
  alias Test.Schema, as: S

  test "block names in declaration order" do
    assert [:basic, :extended, :strict] == S.Status.__maru_params__()
    assert [:default] == S.Anonymous.__maru_params__()
    assert [:x] == S.Pair.__maru_params__(:first) |> Enum.map(& &1.name)
  end

  test "the anonymous block is named :default and is not a special case" do
    assert [:a, :b] == S.Anonymous.__maru_params__(:default) |> Enum.map(& &1.name)
    assert [:a, :b] == Schema.resolve(S.Anonymous, only: :default) |> Enum.map(& &1.name)
  end

  test "one function per block" do
    assert Code.ensure_loaded?(S.Status)
    assert function_exported?(S.Status, :__maru_params__, 1)

    for name <- S.Status.__maru_params__() do
      assert [%Maru.Params.Runtime{} | _] = S.Status.__maru_params__(name)
    end
  end

  test "an unknown block name raises" do
    assert_raise FunctionClauseError, fn ->
      apply(S.Status, :__maru_params__, [:nope])
    end
  end

  test "reads: defaults to []" do
    assert [] == S.Status.__maru_reads__()
    assert [:subtype] == S.AddressWidget.__maru_reads__()
  end

  test "__maru_given__ records the literal condition pairs of a block" do
    assert [subtype: :address, status: :success] == S.AddressWidget.__maru_given__(:default)
    assert [] == S.Pair.__maru_given__(:first)
    assert [status: :error] == S.Status.__maru_given__(:strict)
  end

  test "__maru_includes__ records what the include site knew locally" do
    assert [:default] == S.AddressWidget.__maru_includes__()

    assert [
             %{
               path: [:payload],
               module: Test.Schema.Status,
               opts: [only: :basic],
               preceding: []
             }
           ] == S.AddressWidget.__maru_includes__(:default)
  end

  test "struct: and derive:" do
    assert %Test.Schema.WithStruct{id: nil, name: nil, note: nil} = %Test.Schema.WithStruct{}

    assert {:ok, ~s|{"id":1,"name":"x","note":null}|} =
             Jason.encode(%S.WithStruct{id: 1, name: "x"})
  end

  test "resolve/2 with no option takes every block in declaration order" do
    assert [:x, :y] == Schema.resolve(S.Pair) |> Enum.map(& &1.name)
  end

  test "resolve/2 with only: an atom and only: a list" do
    assert [:y] == Schema.resolve(S.Pair, only: :second) |> Enum.map(& &1.name)
    assert [:y, :x] == Schema.resolve(S.Pair, only: [:second, :first]) |> Enum.map(& &1.name)
  end

  test "resolve/2 with except:" do
    assert [:y] == Schema.resolve(S.Pair, except: :first) |> Enum.map(& &1.name)
    assert [] == Schema.resolve(S.Pair, except: [:first, :second]) |> Enum.map(& &1.name)
  end

  test "resolve/2 with an unknown block name raises" do
    assert_raise ArgumentError, ~r/params block \[:nope\] not found in Test.Schema.Pair/, fn ->
      Schema.resolve(S.Pair, only: [:first, :nope])
    end

    assert_raise ArgumentError, ~r/params block \[:nope\] not found in Test.Schema.Pair/, fn ->
      Schema.resolve(S.Pair, except: :nope)
    end
  end

  test "resolve/2 with both only: and except: raises" do
    assert_raise ArgumentError, ":only and :except are in conflict!", fn ->
      Schema.resolve(S.Pair, only: :first, except: :second)
    end
  end

  test "resolve/2 of a module which isn't a schema raises" do
    assert_raise UndefinedFunctionError, fn ->
      Schema.resolve(Enum)
    end
  end
end
