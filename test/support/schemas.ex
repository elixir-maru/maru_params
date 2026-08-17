defmodule Test.Schema.Status do
  @moduledoc """
  Several named blocks, each self contained so that `only:` / `except:` are
  safe: no block depends on a sibling block.
  """

  use Maru.Params.Schema

  params :basic do
    requires :status, Atom, values: [:success, :failed, :error]

    optional :errors, List do
      requires :code, Integer
      optional :message, String
    end
  end

  params :extended do
    requires :status, Atom, values: [:success, :failed, :error, :skipped]
  end

  params :strict do
    requires :status, Atom, values: [:success, :failed, :error]

    given status: :error do
      requires :errors, List do
        requires :code, Integer
        optional :message, String
      end
    end
  end
end

defmodule Test.Schema.Pair do
  @moduledoc "Two independent named blocks."

  use Maru.Params.Schema

  params :first do
    optional :x, String
  end

  params :second do
    optional :y, String
  end
end

defmodule Test.Schema.Shared do
  @moduledoc "Declares the `xx` subtree itself, so reuse starts at `xx`."

  use Maru.Params.Schema

  params do
    requires :xx, Map do
      requires :aa, String
      optional :bb, Integer
    end
  end
end

defmodule Test.Schema.Anonymous do
  @moduledoc "One anonymous block, named `:default`."

  use Maru.Params.Schema

  params do
    requires :a, String
    optional :b, Integer
  end
end

defmodule Test.Schema.Required do
  @moduledoc "Holds a required param, to check `include` under a `given`."

  use Maru.Params.Schema

  params do
    requires :must, String
  end
end

defmodule Test.Schema.Conditional do
  @moduledoc "Carries its own `given`, on a field it declares itself."

  use Maru.Params.Schema

  params do
    optional :flag, Boolean

    given flag: true do
      requires :must, String
    end
  end
end

defmodule Test.Schema.AddressWidget do
  @moduledoc """
  The `given` which selects this widget lives here, so the module declares the
  field it reads from the enclosing level.
  """

  use Maru.Params.Schema, reads: [:subtype]

  alias Test.Schema

  params do
    given subtype: :address do
      requires :payload, Map do
        include Schema.Status, only: :basic

        given status: :success do
          requires :data, Map do
            requires :city, String
            requires :zipcode, String, regex: ~r/^\d{5}$/
          end
        end

        given fn %{status: status} -> status not in [:success] end do
          optional :data, Map
        end
      end
    end
  end
end

defmodule Test.Schema.MotivationWidget do
  @moduledoc """
  Also requires `label`, which the enclosing level declares as optional: that
  level then holds two params named `label` and both run, in order.
  """

  use Maru.Params.Schema, reads: [:subtype]

  alias Test.Schema

  params do
    given subtype: :motivation do
      requires :label, String

      requires :payload, Map do
        include Schema.Status, only: :basic

        requires :data, List do
          requires :slug, String
        end
      end
    end
  end
end

defmodule Test.Schema.WithStruct do
  @moduledoc "Defines a struct out of the params it declares."

  use Maru.Params.Schema, struct: true, derive: Jason.Encoder

  params do
    requires :id, Integer
    optional :name, String
  end

  params :extra do
    optional :note, String
  end
end

defmodule Test.PlainType do
  @moduledoc "A type which doesn't live under `Maru.Params.Types`."

  use Maru.Params.Type

  def validator_arguments, do: [:values]

  def parse(input, _), do: {:ok, "plain:#{input}"}

  def validate(parsed, values: values) do
    if parsed in values do
      {:ok, parsed}
    else
      {:error, :validate, "allowed values: #{Enum.join(values, ", ")}"}
    end
  end
end
