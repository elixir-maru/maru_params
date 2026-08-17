defmodule Maru.Params.GivenTest do
  use ExUnit.Case, async: true

  defmodule T do
    use Maru.Params.TestHelper

    params :nested do
      optional :a, Atom, values: [:a1]
      optional :b, Atom, values: [:b1]

      given a: :a1 do
        optional :x, String

        given b: :b1 do
          optional :y, String
        end

        optional :z, String
      end
    end

    params :nested_atom_form do
      optional :a, Boolean

      given :a do
        optional :x, String

        given a: true do
          optional :y, String
        end
      end
    end

    params :three_levels do
      optional :a, Atom, values: [:a1]
      optional :b, Atom, values: [:b1]
      optional :c, Atom, values: [:c1]

      given a: :a1 do
        given b: :b1 do
          given c: :c1 do
            optional :x, String
          end

          optional :y, String
        end

        optional :z, String
      end

      optional :w, String
    end

    params :nested_level do
      optional :outer, Map do
        optional :a, Atom, values: [:a1]

        given a: :a1 do
          optional :x, String
        end
      end

      optional :after, String
    end

    params :outer_first do
      optional :type, Atom, values: [:x]

      given type: :x do
        optional :flag, Boolean

        # this clause only matches when `flag` is in the result
        given fn %{flag: flag} -> flag end do
          optional :extra, String
        end
      end
    end

    params :unchecked_form do
      given fn result -> Map.get(result, :not_declared) == 1 end do
        optional :x, String
      end

      given &match?(%{not_declared: 1}, &1) do
        optional :y, String
      end
    end
  end

  test "a nested given keeps the outer condition" do
    assert %{} == T.nested(%{"x" => "x", "y" => "y", "z" => "z"})

    assert %{b: :b1} == T.nested(%{"b" => "b1", "x" => "x", "y" => "y", "z" => "z"})

    assert %{a: :a1, x: "x", z: "z"} ==
             T.nested(%{"a" => "a1", "x" => "x", "y" => "y", "z" => "z"})

    assert %{a: :a1, b: :b1, x: "x", y: "y", z: "z"} ==
             T.nested(%{"a" => "a1", "b" => "b1", "x" => "x", "y" => "y", "z" => "z"})
  end

  test "a sibling after a nested given keeps its condition" do
    # `z` is declared after the `given b: :b1` block and still only parsed
    # under `a: :a1`
    assert %{} == T.nested(%{"z" => "z"})
    assert %{a: :a1, z: "z"} == T.nested(%{"a" => "a1", "z" => "z"})
  end

  test "three levels of given compose, and each level is restored after its block" do
    all = %{"x" => "x", "y" => "y", "z" => "z", "w" => "w"}
    conditions = %{"a" => "a1", "b" => "b1", "c" => "c1"}

    assert %{w: "w"} == T.three_levels(all)

    assert %{a: :a1, z: "z", w: "w"} == T.three_levels(Map.merge(all, %{"a" => "a1"}))

    assert %{a: :a1, b: :b1, y: "y", z: "z", w: "w"} ==
             T.three_levels(Map.merge(all, %{"a" => "a1", "b" => "b1"}))

    assert %{a: :a1, b: :b1, c: :c1, x: "x", y: "y", z: "z", w: "w"} ==
             T.three_levels(Map.merge(all, conditions))

    assert %{b: :b1, c: :c1, w: "w"} ==
             T.three_levels(Map.merge(all, %{"b" => "b1", "c" => "c1"}))
  end

  test "the atom form composes too" do
    assert %{} == T.nested_atom_form(%{"x" => "x", "y" => "y"})
    assert %{a: false, x: "x"} == T.nested_atom_form(%{"a" => "false", "x" => "x", "y" => "y"})

    assert %{a: true, x: "x", y: "y"} ==
             T.nested_atom_form(%{"a" => "true", "x" => "x", "y" => "y"})
  end

  test "a condition doesn't leak out of a nested block" do
    assert %{outer: %{}, after: "after"} ==
             T.nested_level(%{"outer" => %{"x" => "x"}, "after" => "after"})

    assert %{outer: %{a: :a1, x: "x"}, after: "after"} ==
             T.nested_level(%{"outer" => %{"a" => "a1", "x" => "x"}, "after" => "after"})
  end

  test "an inner condition only runs when the outer one holds" do
    # the inner fn does not match a result without `flag`, so it must be
    # short-circuited by the outer condition, not evaluated first
    assert %{} == T.outer_first(%{"extra" => "e"})

    assert %{type: :x, flag: true, extra: "e"} ==
             T.outer_first(%{"type" => "x", "flag" => "true", "extra" => "e"})

    assert %{type: :x, flag: false} ==
             T.outer_first(%{"type" => "x", "flag" => "false", "extra" => "e"})
  end

  test "the fn and & forms are not checked" do
    assert %{} == T.unchecked_form(%{"x" => "x", "y" => "y"})
  end

  test "given on an undeclared key raises at compile time" do
    assert_raise CompileError, ~r/given condition reads \[:b\]/, fn ->
      defmodule UndeclaredKey do
        use Maru.Params.TestHelper

        params :t do
          optional :a, String

          given b: 1 do
            optional :c, String
          end
        end
      end
    end
  end

  test "given on a key declared later at the same level raises at compile time" do
    assert_raise CompileError, ~r/given condition reads \[:b\]/, fn ->
      defmodule KeyDeclaredLater do
        use Maru.Params.TestHelper

        params :t do
          given b: 1 do
            optional :c, String
          end

          optional :b, Integer
        end
      end
    end
  end

  test "given on a key declared at the enclosing level raises at compile time" do
    assert_raise CompileError, ~r/given condition reads \[:a\]/, fn ->
      defmodule KeyDeclaredOutside do
        use Maru.Params.TestHelper

        params :t do
          optional :a, String

          optional :nested, Map do
            given a: "a" do
              optional :c, String
            end
          end
        end
      end
    end
  end

  test "given passes when the name is in reads:" do
    defmodule DeclaredInReads do
      use Maru.Params.Schema, reads: [:subtype]

      params do
        given subtype: :address do
          optional :c, String
        end
      end
    end

    assert [:default] == DeclaredInReads.__maru_params__()
    assert [:subtype] == DeclaredInReads.__maru_reads__()
  end

  test "reads: only applies to the top level of the schema" do
    # a nested level starts with a fresh result and can never see the field
    assert_raise CompileError, ~r/given condition reads \[:subtype\]/, fn ->
      defmodule NestedReads do
        use Maru.Params.Schema, reads: [:subtype]

        params do
          requires :payload, Map do
            given subtype: :address do
              optional :x, String
            end
          end
        end
      end
    end
  end

  test "given is not checked when an include precedes at that level" do
    defmodule IncludePrecedes do
      use Maru.Params.TestHelper

      params :t do
        include Test.Schema.Pair, only: :first

        given x: "go" do
          requires :z, String
        end
      end
    end

    assert %{} == IncludePrecedes.t(%{"z" => "z"})
    assert %{x: "go", z: "z"} == IncludePrecedes.t(%{"x" => "go", "z" => "z"})
  end
end
