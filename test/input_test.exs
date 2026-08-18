defmodule Maru.Params.InputTest do
  use ExUnit.Case, async: true

  alias Maru.Params.ParseError

  defmodule T do
    use Maru.Params.TestHelper

    params :flat do
      requires :a, String
    end

    params :nested do
      requires :map, Map do
        requires :a, String
      end
    end

    params :custom_type do
      # no `Map |>` in front of the custom type on purpose
      optional :a, CustomTypeB
    end

    params :struct_type do
      optional :a, Test.CustomTypeA
    end

    params :dual_type do
      # this name exists both as Test.DualType and Maru.Params.Types.Test.DualType
      optional :d, Test.DualType
    end

    params :plain_type do
      optional :p, Test.PlainType
      optional :ps, List[Test.PlainType]
      optional :pv, Test.PlainType, values: ["plain:ok"]
    end
  end

  test "a non map input yields a ParseError, not a BadMapError" do
    error =
      assert_raise ParseError, ~r/unknown input format, expected Map, got: \[\]/, fn ->
        T.flat([])
      end

    assert :parse == error.step
    assert [] == error.path
    assert is_nil(error.attribute)

    assert_raise ParseError, ~r/unknown input format, expected Map, got: "x"/, fn ->
      T.flat("x")
    end
  end

  test "a non map nested input yields a ParseError" do
    error =
      assert_raise ParseError, ~r/Error Parsing Parameter `map`/, fn ->
        T.nested(%{"map" => "x"})
      end

    assert [:map] == error.path
  end

  test "a custom type guards its input without a Map stage" do
    error =
      assert_raise ParseError, ~r/Error Parsing Parameter `a`.*expected Map, got: "x"/, fn ->
        T.custom_type(%{"a" => "x"})
      end

    assert [:a] == error.path

    error =
      assert_raise ParseError, ~r/Error Parsing Parameter `a`.*expected Map, got: \[1\]/, fn ->
        T.struct_type(%{"a" => [1]})
      end

    assert [:a] == error.path
  end

  test "a name taken under Maru.Params.Types resolves there, as 0.2.13 did" do
    assert %{d: "namespace:1"} == T.dual_type(%{"d" => 1})
  end

  test "a type module outside Maru.Params.Types resolves when the name is free" do
    assert %{p: "plain:1"} == T.plain_type(%{"p" => 1})
    assert %{ps: ["plain:1", "plain:2"]} == T.plain_type(%{"ps" => [1, 2]})
    assert %{pv: "plain:ok"} == T.plain_type(%{"pv" => "ok"})

    assert_raise ParseError, ~r/Error Validating Parameter `pv`/, fn ->
      T.plain_type(%{"pv" => "no"})
    end
  end

  test "a module which isn't a type resolves under Maru.Params.Types" do
    # `Test.CustomTypeA` exists as a struct, the type module is
    # `Maru.Params.Types.Test.CustomTypeA`
    assert %Test.CustomTypeA{id: 1} = T.struct_type(%{"a" => %{"id" => "1"}}).a
  end

  test "buildin types are not shadowed by same named Elixir modules" do
    defmodule Buildin do
      use Maru.Params.TestHelper

      params :t do
        optional :string, String
        optional :integer, Integer
        optional :float, Float
        optional :atom, Atom
        optional :map, Map
        optional :list, List[Integer]
        optional :datetime, DateTime, format: :unix
      end
    end

    assert %{
             string: "1",
             integer: 1,
             float: 1.5,
             atom: :a,
             map: %{"a" => 1},
             list: [1],
             datetime: ~U[1970-01-01 00:00:01Z]
           } ==
             Buildin.t(%{
               "string" => 1,
               "integer" => "1",
               "float" => "1.5",
               "atom" => "a",
               "map" => %{"a" => 1},
               "list" => ["1"],
               "datetime" => 1
             })
  end
end
