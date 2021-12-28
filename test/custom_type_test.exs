defmodule Maru.Params.CustomTypeTest do
  use ExUnit.Case, async: true

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

  test "derive" do
    assert {:ok, ~s|{"id":1,"name":"11"}|} = Jason.encode(%Test.CustomTypeA{id: 1, name: "11"})
  end
end
