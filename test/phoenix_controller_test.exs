defmodule Maru.Params.PhoenixControllerTest do
  use ExUnit.Case, async: true

  defmodule TestController do
    use Maru.Params.PhoenixController

    params :index do
      requires :a, String
      requires :b, Integer
    end

    def index(_conn, params), do: params

    params :create do
      requires :c, String
      requires :d, Integer
    end

    def create(_conn, params), do: params
  end

  test "phoenix controller" do
    assert %{a: "1", b: 1} = TestController.index([], %{"a" => "1", "b" => 1})
    assert %{c: "1", d: 1} = TestController.create([], %{"c" => "1", "d" => 1})
  end
end
