defmodule Maru.Params.Schema do
  @moduledoc """
  A module holding named params blocks which other modules reuse with `include`.

      defmodule MyApp.Params.Address do
        use Maru.Params.Schema

        params :basic do
          requires :city, String
          requires :zipcode, String
        end

        params :full do
          requires :address_line_1, String
          requires :city, String
          requires :zipcode, String
        end
      end

  `params do ... end` defines the anonymous block, named `:default`.

  ## Options

    * `:reads` - field names the `given` conditions of this schema read from the
      level it is included into, defaults to `[]`
    * `:struct` and `:derive` - define a struct from the declared params, same
      options as `Maru.Params.TypeBuilder`

  ## Generated functions

      __maru_params__()          # block names in declaration order
      __maru_params__(:basic)    # params runtime of one block
      __maru_reads__()           # the `reads:` option
      __maru_given__(:basic)     # literal key/value pairs of the block's givens
      __maru_includes__(:basic)  # includes recorded in the block, checked by
                                 # Maru.Params.verify_all/1
  """

  defmacro __using__(options) do
    quote do
      use Maru.Params.Builder
      import unquote(__MODULE__), only: [params: 1, params: 2]
      Module.register_attribute(__MODULE__, :maru_blocks, accumulate: true)
      @maru_reads unquote(Keyword.get(options, :reads, []))
      @maru_struct unquote(Keyword.get(options, :struct, false))
      @maru_derive unquote(Keyword.get(options, :derive, []))
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro params(do: block) do
    quote do
      unquote(block)
      @maru_blocks {:default, Maru.Params.Builder.pop_block(__ENV__)}
    end
  end

  defmacro params(name, do: block) do
    quote do
      unquote(block)
      @maru_blocks {unquote(name), Maru.Params.Builder.pop_block(__ENV__)}
    end
  end

  defmacro __before_compile__(%Macro.Env{module: module}) do
    blocks = module |> Module.get_attribute(:maru_blocks) |> Enum.reverse()

    params_funcs =
      Enum.map(blocks, fn {name, block} ->
        params_runtime = Maru.Params.Builder.runtime_list(block.params)

        quote do
          def __maru_params__(unquote(name)), do: unquote(params_runtime)
        end
      end)

    struct_ast =
      if Module.get_attribute(module, :maru_struct) do
        attributes =
          for {_name, block} <- blocks,
              param <- block.params,
              not Map.has_key?(param, :include),
              uniq: true do
            param |> Map.get(:info) |> Keyword.get(:name)
          end

        quote do
          @derive @maru_derive
          defstruct unquote(attributes)
        end
      end

    quote do
      def __maru_params__, do: unquote(Enum.map(blocks, fn {name, _block} -> name end))
      unquote(params_funcs)
      def __maru_reads__, do: @maru_reads
      unquote(Maru.Params.Builder.metadata_ast(blocks))
      unquote(struct_ast)
    end
  end

  @doc """
  Resolve the params runtime an `include` refers to, called at runtime by the
  code `include` generated.
  """
  def resolve(module, opts \\ []) do
    all = module.__maru_params__()

    names =
      case {opts[:only], opts[:except]} do
        {nil, nil} -> all
        {only, nil} -> check_block_names!(module, List.wrap(only), all)
        {nil, except} -> all -- check_block_names!(module, List.wrap(except), all)
        {_, _} -> raise ArgumentError, ":only and :except are in conflict!"
      end

    Enum.flat_map(names, &module.__maru_params__(&1))
  end

  defp check_block_names!(module, names, all) do
    case names -- all do
      [] ->
        names

      missing ->
        raise ArgumentError,
              "params block #{inspect(missing)} not found in #{inspect(module)}, defined: #{inspect(all)}"
    end
  end
end
