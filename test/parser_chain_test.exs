defmodule Maru.Params.ParserChainTest do
  # capture_io(:stderr, ...) is not safe to run concurrently
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Maru.Params.ParseError

  defmodule Calls do
    @moduledoc false

    def reset, do: Process.put(__MODULE__, 0)
    def count, do: Process.get(__MODULE__, 0)

    def tick(value) do
      Process.put(__MODULE__, count() + 1)
      value
    end
  end

  defmodule T do
    use Maru.Params.TestHelper

    params :func_then_list_of_string do
      requires :uuids, (&{:ok, List.wrap(&1)}) |> List[String]
    end

    params :func_then_list_of_atom do
      optional :names, (&{:ok, List.wrap(&1)}) |> List[Atom], values: [:a, :b]
    end

    params :func_then_list_of_integer do
      requires :ns, (&{:ok, String.split(&1, ",")}) |> List[Integer]
    end

    params :func_then_list_block do
      requires :data, (&{:ok, List.wrap(&1)}) |> List do
        requires :id, Integer
        optional :name, String
      end
    end

    params :func_then_map_block do
      requires :data, (&{:ok, &1}) |> Map do
        requires :id, Integer
      end
    end

    params :func_then_validated_module do
      requires :name, (&{:ok, String.trim(&1)}) |> String, regex: ~r/^[a-z]+$/
    end

    params :func_then_two_modules do
      requires :n, (&{:ok, String.trim(&1)}) |> Base64 |> Integer
    end

    params :counted_func_then_module do
      requires :tagged, (&{:ok, Calls.tick({:ok, &1})}) |> Passthrough
    end

    params :counted_func_then_list do
      requires :ids, (&{:ok, Calls.tick(List.wrap(&1))}) |> List[String]
    end

    params :counted_func_then_two_modules do
      requires :n, (&{:ok, Calls.tick(&1)}) |> Base64 |> Integer
    end
  end

  describe "function piped into a parametric list" do
    test "wraps a bare value" do
      assert %{uuids: ["a"]} = T.func_then_list_of_string(%{"uuids" => "a"})
    end

    test "passes a list through" do
      assert %{uuids: ["a", "b"]} = T.func_then_list_of_string(%{"uuids" => ["a", "b"]})
    end

    test "applies the inner type to every element" do
      assert %{names: [:a, :b]} = T.func_then_list_of_atom(%{"names" => ["a", "b"]})
    end

    test "applies the inner type validators to every element" do
      assert_raise ParseError, ~r/Validating Parameter `names\[1\]`/, fn ->
        T.func_then_list_of_atom(%{"names" => ["a", "c"]})
      end
    end

    test "applies the inner type parser to every element" do
      assert %{ns: [1, 2]} = T.func_then_list_of_integer(%{"ns" => "1,2"})
    end

    test "propagates an inner parse error" do
      assert_raise ParseError, ~r/Parsing Parameter `ns\[1\]`/, fn ->
        T.func_then_list_of_integer(%{"ns" => "1,x"})
      end
    end
  end

  describe "function piped into a nested block" do
    test "parses children of every list item" do
      assert %{data: [%{id: 1, name: "x"}]} =
               T.func_then_list_block(%{"data" => %{"id" => "1", "name" => "x"}})

      assert %{data: [%{id: 1}, %{id: 2}]} =
               T.func_then_list_block(%{"data" => [%{"id" => "1"}, %{"id" => "2"}]})
    end

    test "parses children of a map" do
      assert %{data: %{id: 1}} = T.func_then_map_block(%{"data" => %{"id" => "1"}})
    end

    test "propagates a child parse error" do
      assert_raise ParseError, ~r/Parsing Parameter `data\[0\].id`/, fn ->
        T.func_then_list_block(%{"data" => [%{"id" => "x"}]})
      end
    end
  end

  describe "function piped into module parsers" do
    test "runs the module validators of a non-leading step" do
      assert %{name: "abc"} = T.func_then_validated_module(%{"name" => "  abc  "})

      assert_raise ParseError, ~r/Validating Parameter `name`/, fn ->
        T.func_then_validated_module(%{"name" => "  aBc  "})
      end
    end

    test "chains through more than one module step" do
      assert %{n: 11} = T.func_then_two_modules(%{"n" => " MTE= "})
    end

    test "propagates an error raised by a later step" do
      assert_raise ParseError, ~r/Parsing Parameter `n`/, fn ->
        T.func_then_two_modules(%{"n" => " not-base64 "})
      end
    end
  end

  describe "the preceding chain is evaluated exactly once" do
    setup do
      Calls.reset()
      :ok
    end

    # Regression: the {:module, _} branch of do_build_parser/2 used to re-inline the
    # whole preceding chain as the argument of module.parse/2. When the preceding
    # step's payload was itself an {:ok, _} shaped tuple, the re-inlined copy matched
    # its own success clause and re-applied that step.
    test "with an {:ok, _} shaped payload" do
      assert %{tagged: {:ok, "a"}} = T.counted_func_then_module(%{"tagged" => "a"})
      assert 1 = Calls.count()
    end

    test "with a list payload" do
      assert %{ids: ["a"]} = T.counted_func_then_list(%{"ids" => "a"})
      assert 1 = Calls.count()
    end

    test "with two following module steps" do
      assert %{n: 11} = T.counted_func_then_two_modules(%{"n" => "MTE="})
      assert 1 = Calls.count()
    end
  end

  test "chained parsers compile without warnings" do
    output =
      capture_io(:stderr, fn ->
        Code.compile_string("""
        defmodule Maru.Params.ParserChainTest.Warnings do
          use Maru.Params.TestHelper

          params :chained do
            requires :uuids, (&{:ok, List.wrap(&1)}) |> List[String]
            optional :names, (&{:ok, String.split(&1, ",")}) |> List[Atom], values: [:a, :b]
            requires :name, (&{:ok, String.trim(&1)}) |> String
            requires :n, (&{:ok, String.trim(&1)}) |> Base64 |> Integer

            requires :data, (&{:ok, List.wrap(&1)}) |> List do
              requires :id, Integer
            end
          end
        end
        """)
      end)

    assert output == "", "expected no compiler warning, got:\n#{output}"
  end
end
