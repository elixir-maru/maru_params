defmodule Maru.Params.CustomTypeTest do
  use ExUnit.Case, async: true

  alias Maru.Params.TypeError

  defmodule T do
    use Maru.Params.TestHelper

    params :custom_type do
      optional :a, Test.CustomTypeA
      optional :b, CustomTypeB
      optional :c, CustomTypeC
    end
  end

  test "custom type" do
    assert %{a: %Test.CustomTypeA{id: 1, name: "2"}} =
             T.custom_type(%{"a" => %{"id" => "1", "name" => 2}})

    assert %{b: %{id: 1, name: "2"}} = T.custom_type(%{"b" => %{"id" => "1", "name" => 2}})

    assert %{
             c: %{
               map: %{
                 m1: [
                   %Test.CustomTypeA{id: 1, name: "11"},
                   %Test.CustomTypeA{id: 2, name: "22"}
                 ],
                 m2: %{d1: "d1", d2: 22}
               }
             }
           } =
             T.custom_type(%{
               "c" => %{
                 "map" => %{
                   "m1" => [%{"id" => "1", "name" => 11}, %{"id" => 2, "name" => "22"}],
                   "m2" => %{"d1" => "d1", "d2" => 22}
                 }
               }
             })
  end

  test "custom type atom key" do
    assert %{a: %Test.CustomTypeA{id: 1, name: "2"}} =
             T.custom_type(%{a: %{id: "1", name: 2}}, keys: :atoms!)

    assert %{b: %{id: 1, name: "2"}} = T.custom_type(%{b: %{id: 1, name: 2}}, keys: :atoms!)
  end

  test "derive" do
    assert {:ok, ~s|{"id":1,"name":"11"}|} = Jason.encode(%Test.CustomTypeA{id: 1, name: "11"})
  end

  test "undefined type" do
    assert_raise TypeError, fn ->
      defmodule T2 do
        use Maru.Params.TestHelper

        params :test do
          optional :a, UndefinedCustomType
        end
      end
    end
  end
end
