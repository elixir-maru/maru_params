defmodule Maru.Params.Types.Passthrough do
  @moduledoc """
  Test only type: returns its input unchanged.

  Used to exercise parser chains whose preceding step yields a payload that no
  buildin type would accept, e.g. an `{:ok, _}` shaped tuple.
  """

  use Maru.Params.Type
end
