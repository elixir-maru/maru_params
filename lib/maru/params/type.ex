defmodule Maru.Params.Type do
  defmacro __using__(_) do
    quote do
      def parser_arguments, do: []

      def validator_arguments, do: []

      def parse(input, _), do: {:ok, input}

      def validate(_, _), do: :ok

      defoverridable parser_arguments: 0, validator_arguments: 0, parse: 2, validate: 2
    end
  end
end
