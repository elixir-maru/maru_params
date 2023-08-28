defmodule Maru.Params.TypeError do
  defexception [:type, :reason]

  def message(%{type: type, reason: reason}) do
    "Type #{type} Error: #{reason}"
  end
end

defmodule Maru.Params.ParseError do
  defexception [:attribute, :step, :reason]

  def message(%{step: :parse} = e) do
    "Error Parsing Parameter `#{e.attribute}`: #{e.reason}"
  end

  def message(%{step: :validate} = e) do
    "Error Validating Parameter `#{e.attribute}`: #{e.reason}"
  end
end
