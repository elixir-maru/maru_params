defmodule Maru.Params.TypeBuilder do
  defmacro __using__(options) do
    derive = Keyword.get(options, :derive, [])

    quote do
      require Protocol
      use Maru.Params.Builder
      Module.register_attribute(__MODULE__, :types, accumulate: true)
      import unquote(__MODULE__)
      @struct_derive unquote(derive)
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro type(module, do: block) do
    type = Maru.Params.Builder.expand_alias(module, __CALLER__)

    quote do
      unquote(block)
      @types {unquote(type), :type, Maru.Params.Builder.pop_params(__ENV__)}
    end
  end

  defmacro type(module, options, do: block) do
    type = Maru.Params.Builder.expand_alias(module, __CALLER__)
    struct? = options == :struct || Keyword.get(options, :struct, false)
    struct_or_type = (struct? && :struct) || :type

    quote do
      unquote(block)
      @types {unquote(type), unquote(struct_or_type), Maru.Params.Builder.pop_params(__ENV__)}
    end
  end

  defmacro __before_compile__(%Macro.Env{module: module}) do
    derive = Module.get_attribute(module, :struct_derive)

    module
    |> Module.get_attribute(:types)
    |> Enum.map(fn
      {type, :type, params} ->
        params_runtime = Enum.map(params, &Map.get(&1, :runtime))
        maru_type_module = Module.concat(Maru.Params.Types, type)

        quote do
          defmodule unquote(maru_type_module) do
            use Maru.Params.Type
            def parser_arguments, do: [:options]

            def parse(input, args) do
              options = Map.get(args, :options, [])

              unquote(params_runtime)
              |> Maru.Params.Runtime.parse_params(input, options)
              |> then(&{:ok, &1})
            end
          end
        end

      {type, :struct, params} ->
        params_runtime = Enum.map(params, &Map.get(&1, :runtime))
        maru_type_module = Module.concat(Maru.Params.Types, type)

        attributes =
          Enum.map(params, fn param -> param |> Map.get(:info) |> Keyword.get(:name) end)

        quote do
          defmodule unquote(type) do
            @derive unquote(derive)
            defstruct unquote(attributes)
          end

          defmodule unquote(maru_type_module) do
            use Maru.Params.Type
            def parser_arguments, do: [:options]

            def parse(input, args) do
              options = Map.get(args, :options, [])

              unquote(params_runtime)
              |> Maru.Params.Runtime.parse_params(input, options)
              |> then(&{:ok, struct(unquote(type), &1)})
            end
          end
        end
    end)
  end
end
