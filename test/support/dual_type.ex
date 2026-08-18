defmodule Test.DualType do
  @moduledoc """
  Test only type: a maru type in the user's own namespace whose name is also
  taken under `Maru.Params.Types`.

  Used to verify the lookup order: the namespace wins the name, exactly as
  0.2.13 resolved it, and this module is never picked.
  """

  use Maru.Params.Type

  def parse(input, _), do: {:ok, "own:#{input}"}
end

defmodule Maru.Params.Types.Test.DualType do
  @moduledoc """
  The namesake of `Test.DualType` under the buildin namespace.
  """

  use Maru.Params.Type

  def parse(input, _), do: {:ok, "namespace:#{input}"}
end
