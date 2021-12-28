defmodule CustomTypes1 do
  use Maru.Params.TypeBuilder, derive: Jason.Encoder

  type Test.CustomTypeA, :struct do
    requires :id, Integer
    optional :name, String
  end
end

defmodule CustomTypes2 do
  use Maru.Params.TypeBuilder

  type CustomTypeB do
    requires :id, Integer
    optional :name, String
  end

  type CustomTypeC do
    optional :map, Map do
      optional :m1, List[Test.CustomTypeA]

      optional :m2, Map do
        optional :d1, String
        optional :d2, Integer
      end
    end
  end
end
