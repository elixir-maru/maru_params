defmodule Maru.Params.Builder do
  alias Maru.Params.Runtime

  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)
      Module.register_attribute(__MODULE__, :actions, accumulate: true)
      @params []
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro optional(name, type) do
    type = expand_alias(type, __CALLER__)
    args = Macro.escape(%{__name__: name, __type__: type, __required__: false})

    quote do
      unquote(args) |> build_param() |> push_param(__ENV__)
    end
  end

  defmacro optional(name, type, options) do
    type = expand_alias(type, __CALLER__)

    args =
      %{__name__: name, __type__: type, __required__: false}
      |> Map.merge(Map.new(options))
      |> Macro.escape()

    quote do
      unquote(args) |> build_param() |> push_param(__ENV__)
    end
  end

  defmacro requires(name, type) do
    type = expand_alias(type, __CALLER__)
    args = Macro.escape(%{__name__: name, __type__: type, __required__: true})

    quote do
      unquote(args) |> build_param() |> push_param(__ENV__)
    end
  end

  defmacro requires(name, type, options) do
    type = expand_alias(type, __CALLER__)

    args =
      %{__name__: name, __type__: type, __required__: true}
      |> Map.merge(Map.new(options))
      |> Macro.escape()

    quote do
      unquote(args) |> build_param() |> push_param(__ENV__)
    end
  end

  def build_param(args) do
    accumulator = %{
      args: args,
      runtime:
        quote do
          %Runtime{}
        end
    }

    [:name, :type, :blank_func]
    |> Enum.reduce(accumulator, &do_build_param/2)
    |> Map.take([:runtime])
  end

  defp do_build_param(:name, %{args: args, runtime: runtime}) do
    name = Map.fetch!(args, :__name__)
    source = Map.get(args, :source, to_string(name))

    %{
      args: args,
      runtime:
        quote do
          %{unquote(runtime) | name: unquote(name), source: unquote(source)}
        end
    }
  end

  defp do_build_param(:type, %{args: args, runtime: runtime}) do
    parsers = args |> Map.get(:__type__) |> do_build_type()

    nested =
      parsers
      |> List.last()
      |> case do
        {:module, Maru.Types.Map} -> :map
        {:module, Maru.Types.List} -> :list
        _ -> nil
      end

    func = do_build_parser(parsers, args)

    %{
      args: args,
      runtime:
        quote do
          %{unquote(runtime) | parser_func: unquote(func), nested: unquote(nested)}
        end
    }
  end

  defp do_build_param(:blank_func, %{args: args, runtime: runtime}) do
    has_default? = args |> Map.has_key?(:default)
    required? = args |> Map.fetch!(:__required__)
    name = args |> Map.fetch!(:__name__)
    keep_blank? = args |> Map.get(:keep_blank, false)

    unpassed =
      {has_default?, required?}
      |> case do
        {false, true} -> {:error, :parse, "required #{name}"}
        {false, false} -> :ignore
        {true, _} -> {:ok, args[:default]}
      end
      |> Macro.escape()

    func =
      if keep_blank? do
        quote do
          fn
            {value, true} -> {:ok, value}
            {_, false} -> unquote(unpassed)
          end
        end
      else
        quote do
          fn {_, _} -> unquote(unpassed) end
        end
      end

    %{
      args: args,
      runtime:
        quote do
          %{unquote(runtime) | blank_func: unquote(func)}
        end
    }
  end

  defp do_build_type({:fn, _, _} = func) do
    [{:func, func}]
  end

  defp do_build_type({:&, _, _} = func) do
    [{:func, func}]
  end

  defp do_build_type({:|>, _, [left, right]}) do
    do_build_type(left) ++ do_build_type(right)
  end

  defp do_build_type(type) do
    module = Module.concat(Maru.Params.Types, type)
    module.__info__(:functions)
    [{:module, module}]
  rescue
    UndefinedFunctionError ->
      raise "undefined type"
  end

  def do_build_parser(parsers, args) do
    value = quote do: value

    block =
      Enum.reduce(parsers, value, fn
        {:func, func}, ast ->
          quote do
            case unquote(ast) do
              {:ok, value} -> unquote(func).(value)
              error -> errro
            end
          end

        {:module, module}, ast ->
          parser_args =
            args
            |> Map.take(module.parser_arguments())
            |> Enum.to_list()

          validator_args =
            args
            |> Map.take(module.validator_arguments())
            |> Enum.map(&List.wrap/1)

          quote do
            case unquote(ast) do
              {:ok, value} ->
                Enum.reduce(
                  unquote(validator_args),
                  unquote(module).parse(unquote(ast), unquote(parser_args)),
                  fn
                    validator_arg, {:ok, parsed} ->
                      unquote(module).validate(parsed, validator_arg)

                    _validator_arg, error ->
                      error
                  end
                )

              error ->
                error
            end
          end
      end)

    quote do
      fn unquote(value) -> unquote(block) end
    end
  end

  def push_param(param, %Macro.Env{module: module}) do
    params = Module.get_attribute(module, :params)
    Module.put_attribute(module, :params, params ++ List.wrap(param))
  end

  def pop_params(%Macro.Env{module: module}) do
    params = Module.get_attribute(module, :params)
    Module.put_attribute(module, :params, [])
    params
  end

  def expand_alias(ast, caller) do
    Macro.prewalk(ast, fn
      {:__aliases__, _, _} = module -> Macro.expand(module, caller)
      other -> other
    end)
  end

  defmacro __before_compile__(%Macro.Env{module: module}) do
    module
    |> Module.get_attribute(:actions)
    |> Enum.map(fn {action, params} ->
      params_runtime = Enum.map(params, &Map.get(&1, :runtime))

      quote do
        defoverridable [{unquote(action), 2}]

        def unquote(action)(conn, params) do
          super(conn, Runtime.parse_params(unquote(params_runtime), params))
        end
      end
    end)
  end
end
