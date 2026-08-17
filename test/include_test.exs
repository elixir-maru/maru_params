defmodule Maru.Params.IncludeTest do
  use ExUnit.Case, async: true

  alias Maru.Params.ParseError

  defmodule T do
    use Maru.Params.TestHelper

    alias Test.Schema

    params :anonymous_block do
      include Schema.Anonymous
    end

    params :all_blocks do
      include Schema.Pair
    end

    params :only_atom do
      include Schema.Pair, only: :second
    end

    params :only_list do
      include Schema.Pair, only: [:second, :first]
    end

    params :except do
      include Schema.Pair, except: [:first]
    end

    params :order do
      optional :before, String
      include Schema.Pair
      optional :after, String
    end

    params :two_includes do
      include Schema.Pair, only: :first
      include Schema.Anonymous
    end

    params :in_given do
      optional :kind, Atom, values: [:full]

      given kind: :full do
        include Schema.Required
      end
    end

    params :in_given_with_own_given do
      optional :kind, Atom, values: [:full]

      given kind: :full do
        include Schema.Conditional
      end
    end

    params :nested do
      optional :wrapper, Map do
        include Schema.Status, only: :basic
      end
    end

    params :nested_list do
      optional :items, List do
        include Schema.Status, only: :basic
      end
    end

    params :include_only_child do
      optional :wrapper, Map do
        include Schema.Anonymous
      end
    end

    params :reused do
      optional :a, Map do
        optional :x, Map do
          include Schema.Shared
        end

        optional :b, Map do
          include Schema.Shared
        end
      end
    end

    params :widgets do
      requires :contents, List do
        requires :subtype, Atom, values: [:address, :motivation]
        optional :label, String

        include Schema.AddressWidget
        include Schema.MotivationWidget
      end
    end
  end

  test "include of a module with one anonymous block" do
    assert %{a: "a", b: 1} == T.anonymous_block(%{"a" => "a", "b" => "1"})

    assert_raise ParseError, ~r/Error Parsing Parameter `a`/, fn ->
      T.anonymous_block(%{})
    end
  end

  test "include of every block of a module" do
    assert %{x: "x", y: "y"} == T.all_blocks(%{"x" => "x", "y" => "y"})
  end

  test "include with only: an atom" do
    assert %{y: "y"} == T.only_atom(%{"x" => "x", "y" => "y"})
  end

  test "include with only: a list, in the order given" do
    assert %{x: "x", y: "y"} == T.only_list(%{"x" => "x", "y" => "y"})

    assert [:y, :x] ==
             Maru.Params.Schema.resolve(Test.Schema.Pair, only: [:second, :first])
             |> Enum.map(& &1.name)
  end

  test "include with except:" do
    assert %{y: "y"} == T.except(%{"x" => "x", "y" => "y"})
  end

  test "included params keep the declaration order of the level" do
    assert %{before: "1", x: "2", y: "3", after: "4"} ==
             T.order(%{"before" => "1", "x" => "2", "y" => "3", "after" => "4"})
  end

  test "several includes at one level" do
    assert %{x: "x", a: "a"} == T.two_includes(%{"x" => "x", "a" => "a"})
  end

  test "include inside a given skips the imported params when the condition fails" do
    # `must` is required by the included module and still not parsed
    assert %{} == T.in_given(%{"must" => "m"})
    assert %{kind: :full, must: "m"} == T.in_given(%{"kind" => "full", "must" => "m"})

    assert_raise ParseError, ~r/Error Parsing Parameter `must`/, fn ->
      T.in_given(%{"kind" => "full"})
    end
  end

  test "include inside a given composes with the condition of the included module" do
    assert %{} == T.in_given_with_own_given(%{"flag" => "true"})

    assert %{kind: :full, flag: false} ==
             T.in_given_with_own_given(%{"kind" => "full", "flag" => "false"})

    assert %{kind: :full, flag: true, must: "m"} ==
             T.in_given_with_own_given(%{"kind" => "full", "flag" => "true", "must" => "m"})

    assert_raise ParseError, ~r/Error Parsing Parameter `must`/, fn ->
      T.in_given_with_own_given(%{"kind" => "full", "flag" => "true"})
    end
  end

  test "include inside a nested block places the params at that level" do
    assert %{wrapper: %{status: :success}} ==
             T.nested(%{"wrapper" => %{"status" => "success"}})

    assert %{wrapper: %{status: :error, errors: [%{code: 1, message: "m"}]}} ==
             T.nested(%{
               "wrapper" => %{
                 "status" => "error",
                 "errors" => [%{"code" => "1", "message" => "m"}]
               }
             })

    assert %{items: [%{status: :success}, %{status: :failed}]} ==
             T.nested_list(%{"items" => [%{"status" => "success"}, %{"status" => "failed"}]})
  end

  test "a block holding only an include still resolves as a nested map" do
    assert %{wrapper: %{a: "a"}} == T.include_only_child(%{"wrapper" => %{"a" => "a"}})
  end

  test "ParseError path crosses the include boundary" do
    error =
      assert_raise ParseError, ~r/Error Validating Parameter `wrapper.status`/, fn ->
        T.nested(%{"wrapper" => %{"status" => "unknown"}})
      end

    assert :status == error.attribute
    assert [:wrapper, :status] == error.path

    error =
      assert_raise ParseError, ~r/Error Parsing Parameter `wrapper.errors\[1\].code`/, fn ->
        T.nested(%{
          "wrapper" => %{"status" => "error", "errors" => [%{"code" => 1}, %{"code" => "x"}]}
        })
      end

    assert [:wrapper, :errors, 1, :code] == error.path

    error =
      assert_raise ParseError, ~r/Error Parsing Parameter `items\[1\].status`/, fn ->
        T.nested_list(%{"items" => [%{"status" => "success"}, %{}]})
      end

    assert [:items, 1, :status] == error.path
  end

  test "the same include is reusable at different levels" do
    # `xx` itself comes from the include, under `a.x` and under `a.b`
    assert %{a: %{x: %{xx: %{aa: "1", bb: 2}}, b: %{xx: %{aa: "3"}}}} ==
             T.reused(%{
               "a" => %{
                 "x" => %{"xx" => %{"aa" => "1", "bb" => "2"}},
                 "b" => %{"xx" => %{"aa" => "3"}}
               }
             })

    # each site fails independently, with its own path
    error =
      assert_raise ParseError, ~r/Error Parsing Parameter `a.b.xx.aa`/, fn ->
        T.reused(%{
          "a" => %{
            "x" => %{"xx" => %{"aa" => "1"}},
            "b" => %{"xx" => %{"bb" => "2"}}
          }
        })
      end

    assert [:a, :b, :xx, :aa] == error.path

    # both sites are recorded, each with its own nesting path
    assert [
             %{path: [:a, :x], module: Test.Schema.Shared, opts: [], preceding: []},
             %{path: [:a, :b], module: Test.Schema.Shared, opts: [], preceding: []}
           ] == T.__maru_includes__(:reused)
  end

  test "an imported given reads a field the caller declared earlier" do
    assert %{
             contents: [
               %{
                 subtype: :address,
                 payload: %{status: :success, data: %{city: "c", zipcode: "12345"}}
               }
             ]
           } ==
             T.widgets(%{
               "contents" => [
                 %{
                   "subtype" => "address",
                   "payload" => %{
                     "status" => "success",
                     "data" => %{"city" => "c", "zipcode" => "12345"}
                   }
                 }
               ]
             })

    # the other widget's params are skipped, `payload` is parsed by the
    # matching schema only
    assert %{
             contents: [
               %{
                 subtype: :motivation,
                 label: "l",
                 payload: %{status: :success, data: [%{slug: "s"}]}
               }
             ]
           } ==
             T.widgets(%{
               "contents" => [
                 %{
                   "subtype" => "motivation",
                   "label" => "l",
                   "payload" => %{"status" => "success", "data" => [%{"slug" => "s"}]}
                 }
               ]
             })
  end

  test "several includes at one level dispatch on the field they read" do
    params = fn subtype ->
      %{
        "contents" => [
          %{
            "subtype" => subtype,
            "payload" => %{"status" => "failed", "data" => %{"whatever" => 1}}
          }
        ]
      }
    end

    # address: `data` is optional and untyped when the status isn't :success
    assert %{
             contents: [
               %{subtype: :address, payload: %{status: :failed, data: %{"whatever" => 1}}}
             ]
           } ==
             T.widgets(params.("address"))

    # motivation: `label` and a list `data` are required
    assert_raise ParseError, ~r/Error Parsing Parameter `contents\[0\].label`/, fn ->
      T.widgets(params.("motivation"))
    end
  end

  test "a field declared twice at one level is parsed twice, the later wins" do
    error =
      assert_raise ParseError, ~r/Error Parsing Parameter `contents\[0\].label`/, fn ->
        T.widgets(%{
          "contents" => [
            %{
              "subtype" => "motivation",
              "payload" => %{"status" => "success", "data" => [%{"slug" => "s"}]}
            }
          ]
        })
      end

    assert :label == error.attribute
  end

  test "the error of an unknown block name surfaces at parse time" do
    defmodule UnknownBlock do
      use Maru.Params.TestHelper

      params :t do
        include Test.Schema.Pair, only: :nope
      end
    end

    assert_raise ArgumentError, ~r/params block \[:nope\] not found in Test.Schema.Pair/, fn ->
      UnknownBlock.t(%{})
    end
  end

  test "include of a list raises at compile time" do
    assert_raise CompileError, ~r/include takes one module; write one include per module/, fn ->
      defmodule IncludeList do
        use Maru.Params.TestHelper

        params :t do
          include [Test.Schema.Pair, Test.Schema.Anonymous]
        end
      end
    end
  end

  test "include options must be literal" do
    # a non literal option would be evaluated in the module body and so create
    # a compile time dependency on whatever it calls
    assert_raise CompileError, ~r/include options must be literal/, fn ->
      defmodule NonLiteralOpts do
        use Maru.Params.TestHelper

        params :t do
          include Test.Schema.Pair, only: Test.Schema.Pair.some_blocks()
        end
      end
    end
  end

  test "include with both only: and except: raises at compile time" do
    assert_raise CompileError, ~r/:only and :except are in conflict!/, fn ->
      defmodule IncludeConflict do
        use Maru.Params.TestHelper

        params :t do
          include Test.Schema.Pair, only: :first, except: :second
        end
      end
    end
  end

  test "include records the field names declared before it at that level" do
    assert [
             %{
               path: [:contents],
               module: Test.Schema.AddressWidget,
               opts: [],
               preceding: [:subtype, :label]
             },
             %{
               path: [:contents],
               module: Test.Schema.MotivationWidget,
               opts: [],
               preceding: [:subtype, :label]
             }
           ] == T.__maru_includes__(:widgets)
  end

  test "include inside a phoenix controller action" do
    defmodule Controller do
      use Maru.Params.PhoenixController

      params :create do
        requires :data, Map do
          include Test.Schema.Pair, only: :first
        end
      end

      def create(_conn, params), do: params
    end

    assert %{data: %{x: "x"}} == Controller.create([], %{"data" => %{"x" => "x"}})

    assert [%{path: [:data], module: Test.Schema.Pair, opts: [only: :first]} | _] =
             Controller.__maru_includes__(:create)
  end

  test "include inside a custom type" do
    defmodule Types do
      use Maru.Params.TypeBuilder

      type IncludingType do
        optional :head, String
        include Test.Schema.Pair
      end
    end

    defmodule TypeUser do
      use Maru.Params.TestHelper

      params :t do
        optional :a, IncludingType
      end
    end

    assert %{a: %{head: "h", x: "x", y: "y"}} ==
             TypeUser.t(%{"a" => %{"head" => "h", "x" => "x", "y" => "y"}})
  end
end
