defmodule Maru.Params.MixedTest do
  use ExUnit.Case, async: true

  alias Maru.Params.ParseError

  defmodule T do
    use Maru.Params.TestHelper

    params :nested do
      optional :map, Map do
        optional :m1, Map do
          optional :d1, String
          optional :d2, Integer
        end

        optional :m2, List do
          optional :d1, String
          optional :d2, Integer
        end
      end
    end

    params :pipeline do
      requires :p1, Base64
      requires :p2, Base64 |> Integer
      requires :p3, Json
      requires :p4, Json |> List[Integer]
      requires :p5, Base64 |> Json |> List[Integer]
      requires :p6, List[Base64 |> Integer]
      requires :p7, String |> Atom, style: :downcase, values: [:a, :b]
      requires :p8, Atom |> String, style: :upcase, values: ["A", "B"]
      requires :p9, Json |> List[Atom], values: [:a, :b]
    end

    params :blank_optional do
      optional :a1, String
      optional :a2, String
      optional :a3, String
      optional :b1, String, keep_blank: true
      optional :b2, String, keep_blank: true
      optional :c1, String, default: "test"
      optional :c2, String, default: "test"
      optional :d1, String, keep_blank: true, default: "test"
      optional :d2, String, keep_blank: true, default: "test"
      optional :d3, String, keep_blank: true, default: "test"
    end

    params :blank_requires_1 do
      requires :a, String
    end

    params :blank_requires_2 do
      requires :a, String, keep_blank: true
    end

    params :blank_requires_3 do
      requires :a, String, default: "test"
    end

    params :blank_requires_4 do
      requires :a, String, keep_blank: true, default: "test"
    end

    params :rename do
      optional :x, String, source: :b
      optional :y, String, source: "c"
    end

    params :atoms_keys do
      optional :z, String, source: "do_not_existed_atom"
    end

    params :function do
      optional :fun, (&{:ok, String.split(&1, ",", trim: true)}) |> List[Atom], values: [:a, :c]
    end

    params :given_1 do
      optional :existed, Boolean

      given :existed do
        optional :meta do
          requires :a, String
        end
      end
    end

    params :given_2 do
      optional :style, Atom, values: [:foo, :bar]

      given style: :foo do
        optional :meta do
          requires :foo_str, String
        end
      end

      given style: :bar do
        optional :meta do
          requires :bar_str, String
        end
      end
    end

    params :given_3 do
      optional :style, Atom, values: [:foo, :bar]

      given &match?(%{style: :foo}, &1) do
        optional :meta do
          requires :foo_str, String
        end
      end

      given fn result -> Map.get(result, :style) == :bar end do
        optional :meta do
          requires :bar_str, String
        end
      end
    end
  end

  test "atom" do
    assert %{
             map: %{
               m1: %{d1: "d1", d2: 22},
               m2: [%{d1: "d1", d2: 22}, %{d1: "dx", d2: 222}]
             }
           } =
             T.nested(%{
               "map" => %{
                 "m1" => %{"d1" => "d1", "d2" => 22},
                 "m2" => [%{"d1" => "d1", "d2" => 22}, %{"d1" => "dx", "d2" => 222}]
               }
             })
  end

  test "pipeline" do
    assert %{
             p1: "11",
             p2: 11,
             p3: ["1", "2", "3"],
             p4: [1, 2, 3],
             p5: [1, 2, 3],
             p6: [11, 11],
             p7: :a,
             p8: "B",
             p9: [:b, :a]
           } =
             T.pipeline(%{
               "p1" => "MTE=",
               "p2" => "MTE=",
               "p3" => ~s|["1", "2", "3"]|,
               "p4" => ~s|["1", "2", "3"]|,
               "p5" => "WyIxIiwgIjIiLCAiMyJd",
               "p6" => ["MTE=", "MTE="],
               "p7" => "A",
               "p8" => :b,
               "p9" => ~s|["b", "a"]|
             })
  end

  test "blank optional" do
    assert %{b1: nil, b2: "", c1: "T", c2: "test", d1: "test", d2: nil, d3: ""} =
             T.blank_optional(%{
               "a2" => nil,
               "a3" => "",
               "b1" => nil,
               "b2" => "",
               "c1" => "T",
               "d2" => nil,
               "d3" => ""
             })
  end

  test "blank requires" do
    assert %{a: "a"} = T.blank_requires_1(%{"a" => "a"})

    assert_raise ParseError, ~r/Error Parsing Parameter `a`/, fn ->
      T.blank_requires_1(%{})
    end

    assert_raise ParseError, ~r/Error Parsing Parameter `a`/, fn ->
      T.blank_requires_1(%{a: nil})
    end

    assert_raise ParseError, ~r/Error Parsing Parameter `a`/, fn ->
      T.blank_requires_1(%{a: ""})
    end

    assert %{a: "a"} = T.blank_requires_2(%{"a" => "a"})
    assert %{a: nil} = T.blank_requires_2(%{"a" => nil})
    assert %{a: ""} = T.blank_requires_2(%{"a" => ""})

    assert_raise ParseError, ~r/Error Parsing Parameter `a`/, fn ->
      T.blank_requires_2(%{})
    end

    assert %{a: "a"} = T.blank_requires_3(%{"a" => "a"})
    assert %{a: "test"} = T.blank_requires_3(%{"a" => nil})
    assert %{a: "test"} = T.blank_requires_3(%{"a" => ""})
    assert %{a: "test"} = T.blank_requires_3(%{})

    assert %{a: "a"} = T.blank_requires_4(%{"a" => "a"})
    assert %{a: nil} = T.blank_requires_4(%{"a" => nil})
    assert %{a: ""} = T.blank_requires_4(%{"a" => ""})
    assert %{a: "test"} = T.blank_requires_4(%{})
  end

  test "rename" do
    assert %{x: "x"} = T.rename(%{"b" => "x"}, keys: :strings)
    assert %{y: "y"} = T.rename(%{"c" => "y"}, keys: :strings)
  end

  test "atom key" do
    assert %{x: "x"} = T.rename(%{b: "x"}, keys: :atoms!)
    assert %{y: "y"} = T.rename(%{c: "y"}, keys: :atoms)

    assert_raise ArgumentError, fn ->
      T.atoms_keys(%{"do_not_existed_atom" => "z"}, keys: :atoms!)
    end
  end

  test "function key" do
    assert %{fun: [:c, :a]} = T.function(%{"fun" => "c,a"})
  end

  test "given with existed condition" do
    assert %{existed: true, meta: %{a: "AA"}} =
             T.given_1(%{
               "existed" => "true",
               "meta" => %{
                 "a" => "AA"
               }
             })

    assert %{} = T.given_1(%{})
  end

  test "given with value condition" do
    assert %{} = T.given_2(%{})

    assert %{meta: %{foo_str: "foo"}, style: :foo} =
             T.given_2(%{
               "style" => "foo",
               "meta" => %{
                 "foo_str" => "foo"
               }
             })

    assert %{meta: %{bar_str: "bar"}, style: :bar} =
             T.given_2(%{
               "style" => "bar",
               "meta" => %{
                 "bar_str" => "bar"
               }
             })
  end

  test "given with function condition" do
    assert %{} = T.given_2(%{})

    assert %{meta: %{foo_str: "foo"}, style: :foo} =
             T.given_3(%{
               "style" => "foo",
               "meta" => %{
                 "foo_str" => "foo"
               }
             })

    assert %{meta: %{bar_str: "bar"}, style: :bar} =
             T.given_3(%{
               "style" => "bar",
               "meta" => %{
                 "bar_str" => "bar"
               }
             })
  end
end
