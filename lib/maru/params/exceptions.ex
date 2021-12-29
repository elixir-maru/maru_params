defmodule Maru.Params.TypeError do
  defexception [:type, :reason]

  def message(%{type: type, reason: reason}) do
    "Type #{type} Error: #{reason}"
  end
end

defmodule Maru.Params.ParseError do
  defexception [:attribute, :step, :reason]

  def message(%{step: :parse} = e) do
    "Parse Parameter #{e.attribute} Error: #{e.reason}"
  end

  def message(%{step: :validate} = e) do
    "Validate Parameter #{e.attribute} Error: #{e.reason}"
  end
end
