defmodule Ecto.Enum do
  def values(User, :fruit), do: [:apple]
  def values(Nested.User2, :fruit), do: [:apple]
  def dump_values(User, :fruit), do: ["apple"]
  def dump_values(Nested.User2, :fruit), do: ["apple"]
end

defmodule Maru.Params.TypesTest do
  use ExUnit.Case, async: true

  alias Maru.Params.ParseError

  defmodule T do
    alias Nested.User2
    use Maru.Params.TestHelper

    params :atom do
      optional :role, Atom, values: [:role1, :role2]
      optional :fruit, Atom, ecto_enum: {User, :fruit}
      optional :fruit2, Atom, ecto_enum: {User2, :fruit}
    end

    params :base64 do
      optional :d1, Base64
      optional :d2, Base64, options: [padding: false]
    end

    params :boolean do
      optional :b1, Boolean
      optional :b2, Boolean
    end

    params :datetime do
      optional :d01, DateTime, format: :iso8601
      optional :d02, DateTime, format: :unix
      optional :d03, DateTime, format: {:unix, :microsecond}
      optional :d04, DateTime, format: :iso8601, naive: true
      optional :d05, DateTime, format: :unix, naive: true
      optional :d06, DateTime, format: {:unix, :microsecond}, naive: true
      optional :d07, DateTime, format: :iso8601, truncate: :second
      optional :d08, DateTime, format: :iso8601, naive: true, truncate: :second
      optional :d09, DateTime, format: {:unix, :microsecond}, truncate: :millisecond
      optional :d10, DateTime, format: {:unix, :microsecond}, naive: true, truncate: :second
      optional :d11, DateTime
      optional :d12, DateTime, naive: true
    end

    params :float do
      optional :pi1, Float
      optional :pi2, Float, style: :decimals
    end

    params :integer do
      optional :i1, Integer
      optional :i2, Integer, min: 1
      optional :i3, Integer, max: 11
      optional :i4, Integer, range: 5..10
    end

    params :json do
      optional :j1, Json |> Integer
      optional :j2, Json |> String
      optional :j3, Json |> List[Integer], max_length: 3
      optional :j4, Json, json_library_options: [keys: :atoms]
    end

    params :list do
      optional :l1, List[Integer]
      optional :l2, List[Integer], string_strategy: :codepoints
      optional :l3, List[Integer], string_strategy: :charlist
      optional :l4, List[String], max_length: 2
      optional :l5, List[String], min_length: 2
      optional :l6, List[String], length_range: 2..4
    end

    params :map do
      optional :m1, Map
    end

    params :string do
      optional :s1, String
      optional :s2, String, style: :upcase
      optional :s3, String, style: :downcase
      optional :s4, String, style: :camelcase
      optional :s5, String, style: :snakecase
      optional :s6, String, regex: ~r/^\d{1,3}$/
      optional :s7, String, values: ["x", "y"]
      optional :s8, String, regex: :uuid
    end
  end

  test "atom" do
    assert %{fruit: :apple, role: :role1} = T.atom(%{"role" => "role1", "fruit" => "apple"})

    assert %{fruit2: :apple, role: :role1} = T.atom(%{"role" => "role1", "fruit2" => "apple"})

    assert_raise ParseError, ~r/Parse Parameter role Error/, fn ->
      T.atom(%{"role" => "role3"})
    end

    assert_raise ParseError, ~r/Validate Parameter role Error/, fn ->
      T.atom(%{"role" => "apple"})
    end

    assert_raise ParseError, ~r/Validate Parameter fruit Error/, fn ->
      T.atom(%{"fruit" => "hehe"})
    end
  end

  test "base64" do
    assert %{d2: "foob"} = T.base64(%{"d2" => "Zm9vYg"})

    assert_raise ParseError, ~r/Parse Parameter d1 Error/, fn ->
      T.base64(%{"d1" => "Zm9vYg"})
    end
  end

  test "boolean" do
    assert %{b1: true, b2: false} = T.boolean(%{"b1" => "true", "b2" => false})
  end

  test "datetime" do
    assert %{
             d01: ~U[2015-01-23 21:20:07.123Z],
             d02: ~U[2016-05-24 13:26:08Z],
             d03: ~U[2015-05-25 13:26:08.868569Z],
             d04: ~N[2015-01-23 23:50:07.123],
             d05: ~N[2016-05-24 13:26:08],
             d06: ~N[2015-05-25 13:26:08.868569],
             d07: ~U[2015-01-23 23:50:07Z],
             d08: ~N[2015-01-23 23:50:07],
             d09: ~U[2015-05-25 13:26:08.868Z],
             d10: ~N[2015-05-25 13:26:08]
           } =
             T.datetime(%{
               "d01" => "2015-01-23T23:50:07.123+02:30",
               "d02" => 1_464_096_368,
               "d03" => 1_432_560_368_868_569,
               "d04" => "2015-01-23T23:50:07.123+02:30",
               "d05" => 1_464_096_368,
               "d06" => 1_432_560_368_868_569,
               "d07" => "2015-01-23T23:50:07.123456789Z",
               "d08" => "2015-01-23T23:50:07.123456789Z",
               "d09" => 1_432_560_368_868_569,
               "d10" => 1_432_560_368_868_569
             })

    assert %{d11: ~U[2015-05-25 13:26:08Z]} = T.datetime(%{"d11" => ~U[2015-05-25 13:26:08Z]})
    assert %{d12: ~N[2015-05-25 13:26:08]} = T.datetime(%{"d12" => ~U[2015-05-25 13:26:08Z]})
    assert %{d12: ~N[2015-05-25 13:26:08]} = T.datetime(%{"d12" => ~N[2015-05-25 13:26:08]})

    assert_raise ParseError, ~r/Parse Parameter d11 Error/, fn ->
      T.datetime(%{"d11" => ~N[2015-05-25 13:26:08Z]})
    end
  end

  test "float" do
    d = Decimal.new("3.14")
    assert %{pi1: 3.14, pi2: ^d} = T.float(%{"pi1" => 3.14, "pi2" => 3.14})
    assert %{pi1: 3.14, pi2: ^d} = T.float(%{"pi1" => "3.14x", "pi2" => "3.14"})

    assert_raise ParseError, ~r/Parse Parameter pi1 Error/, fn ->
      T.float(%{"pi1" => "x.xx"})
    end

    assert_raise ParseError, ~r/Parse Parameter pi2 Error/, fn ->
      T.float(%{"pi2" => "3.x"})
    end
  end

  test "integer" do
    assert %{i1: 314, i2: 3, i3: -1, i4: 6} =
             T.integer(%{"i1" => 314, "i2" => "3", "i3" => "-1", "i4" => '6'})

    assert_raise ParseError, ~r/Validate Parameter i2 Error/, fn ->
      T.integer(%{"i2" => 0})
    end

    assert_raise ParseError, ~r/Validate Parameter i3 Error/, fn ->
      T.integer(%{"i3" => 111})
    end

    assert_raise ParseError, ~r/Validate Parameter i4 Error/, fn ->
      T.integer(%{"i4" => 0})
    end

    assert_raise ParseError, ~r/Validate Parameter i4 Error/, fn ->
      T.integer(%{"i4" => 1000})
    end
  end

  test "json" do
    assert %{j1: 115, j2: "hehe", j3: [1, 3, 5], j4: %{}} =
             T.json(%{
               "j1" => ~s|"115"|,
               "j2" => ~s|"hehe"|,
               "j3" => ~s|["1", "3", "5"]|,
               "j4" => ~s|{"a":"1", "b":"b"}|
             })
  end

  test "list" do
    assert %{
             l1: [1],
             l2: [1, 2, 3],
             l3: '123',
             l4: ["1", "2"],
             l5: ["1", "2"],
             l6: ["1", "2"]
           } =
             T.list(%{
               "l1" => ["1"],
               "l2" => "123",
               "l3" => "123",
               "l4" => [1, 2],
               "l5" => [1, 2],
               "l6" => [1, 2]
             })

    assert_raise ParseError, ~r/Validate Parameter l4 Error/, fn ->
      T.list(%{"l4" => ["1", "2", "3"]})
    end

    assert_raise ParseError, ~r/Validate Parameter l5 Error/, fn ->
      T.list(%{"l5" => ["1"]})
    end

    assert_raise ParseError, ~r/Validate Parameter l6 Error/, fn ->
      T.list(%{"l6" => ["12"]})
    end
  end

  test "map" do
    assert %{m1: %{"key" => "value"}} = T.map(%{"m1" => %{"key" => "value"}})
  end

  test "string" do
    assert %{
             s1: "ALO_ha",
             s2: "ALO_HA",
             s3: "alo_ha",
             s4: "ALOHa",
             s5: "alo_ha",
             s6: "34",
             s7: "x",
             s8: "bf4be93a-7d5b-11ec-90d6-0242ac120003"
           } =
             T.string(%{
               "s1" => "ALO_ha",
               "s2" => "ALO_ha",
               "s3" => "ALO_ha",
               "s4" => "ALO_ha",
               "s5" => "ALO_ha",
               "s6" => "34",
               "s7" => "x",
               "s8" => "bf4be93a-7d5b-11ec-90d6-0242ac120003"
             })

    assert_raise ParseError, ~r/Validate Parameter s6 Error/, fn ->
      T.string(%{"s6" => "12313212"})
    end

    assert_raise ParseError, ~r/Validate Parameter s7 Error/, fn ->
      T.string(%{"s7" => "12313212"})
    end

    assert_raise ParseError, ~r/Validate Parameter s8 Error/, fn ->
      T.string(%{"s8" => "not uuid"})
    end
  end
end
