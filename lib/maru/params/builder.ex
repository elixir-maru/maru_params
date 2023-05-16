defmodule Maru.Params.Builder do
  alias Maru.Params.{Runtime, TypeError}

  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)
      @params []
      @given_condition nil
    end
  end

  for {method, required} <- [{:optional, false}, {:requires, true}] do
    defmacro unquote(method)(name, do: block) do
      args = Macro.escape(%{__name__: name, __type__: Map, __required__: unquote(required)})

      quote do
        given_condition = @given_condition
        @given_condition nil
        params = unquote(__MODULE__).pop_params(__ENV__)
        unquote(block)
        nested_params = unquote(__MODULE__).pop_params(__ENV__)
        unquote(__MODULE__).put_params(params, __ENV__)
        @given_condition given_condition

        unquote(args)
        |> Map.put(:children, nested_params)
        |> build_param(__ENV__)
        |> push_param(__ENV__)
      end
    end

    defmacro unquote(method)(name, type) do
      type = expand_alias(type, __CALLER__)
      args = Macro.escape(%{__name__: name, __type__: type, __required__: unquote(required)})

      quote do
        unquote(args) |> build_param(__ENV__) |> push_param(__ENV__)
      end
    end

    defmacro unquote(method)(name, type, do: block) do
      type = expand_alias(type, __CALLER__)
      args = Macro.escape(%{__name__: name, __type__: type, __required__: unquote(required)})

      quote do
        given_condition = @given_condition
        @given_condition nil
        params = unquote(__MODULE__).pop_params(__ENV__)
        unquote(block)
        nested_params = unquote(__MODULE__).pop_params(__ENV__)
        unquote(__MODULE__).put_params(params, __ENV__)
        @given_condition given_condition

        unquote(args)
        |> Map.put(:children, nested_params)
        |> build_param(__ENV__)
        |> push_param(__ENV__)
      end
    end

    defmacro unquote(method)(name, type, options) do
      type = expand_alias(type, __CALLER__)

      options =
        case options do
          [_ | _] -> options |> expand_alias(__CALLER__) |> Macro.escape()
          {{:., _, _}, _, _} -> options
        end

      args = Macro.escape(%{__name__: name, __type__: type, __required__: unquote(required)})

      quote do
        unquote(args)
        |> Map.merge(Map.new(unquote(options)))
        |> build_param(__ENV__)
        |> push_param(__ENV__)
      end
    end

    defmacro unquote(method)(name, type, options, do: block) do
      type = expand_alias(type, __CALLER__)
      options = options |> expand_alias(__CALLER__) |> Map.new()

      args =
        %{__name__: name, __type__: type, __required__: unquote(required)}
        |> Map.merge(options)
        |> Macro.escape()

      quote do
        given_condition = @given_condition
        @given_condition nil
        params = unquote(__MODULE__).pop_params(__ENV__)
        unquote(block)
        nested_params = unquote(__MODULE__).pop_params(__ENV__)
        unquote(__MODULE__).put_params(params, __ENV__)
        @given_condition given_condition

        unquote(args)
        |> Map.put(:children, nested_params)
        |> build_param(__ENV__)
        |> push_param(__ENV__)
      end
    end
  end

  defmacro given(name, do: block) when is_atom(name) do
    func =
      quote do
        fn result -> Map.has_key?(result, unquote(name)) end
      end

    quote do
      @given_condition unquote(Macro.escape(func))
      unquote(block)
      @given_condition nil
    end
  end

  defmacro given(kv_pair, do: block) when is_list(kv_pair) do
    func =
      quote do
        fn result ->
          Enum.all?(unquote(kv_pair), fn {key, value} ->
            Map.get(result, key) == value
          end)
        end
      end

    quote do
      @given_condition unquote(Macro.escape(func))
      unquote(block)
      @given_condition nil
    end
  end

  defmacro given({:fn, _, _} = func, do: block) do
    quote do
      @given_condition unquote(Macro.escape(func))
      unquote(block)
      @given_condition nil
    end
  end

  defmacro given({:&, _, _} = func, do: block) do
    quote do
      @given_condition unquote(Macro.escape(func))
      unquote(block)
      @given_condition nil
    end
  end

  def build_param(args, env) do
    accumulator = %{
      args: Map.put_new(args, :children, []),
      info: [],
      runtime:
        quote do
          %Runtime{}
        end
    }

    [:name, :type, :blank_func, :ignore_func, :children]
    |> Enum.reduce(accumulator, &do_build_param(&1, &2, env))
    |> Map.take([:runtime, :info])
  end

  defp do_build_param(:name, %{args: args, info: info, runtime: runtime}, _env) do
    name = Map.fetch!(args, :__name__)
    source = Map.get(args, :source, name)

    %{
      args: args,
      info: Keyword.put(info, :name, name),
      runtime:
        quote do
          %{unquote(runtime) | name: unquote(name), source: unquote(source)}
        end
    }
  end

  defp do_build_param(:type, %{args: args, info: info, runtime: runtime}, _env) do
    parsers = args |> Map.get(:__type__) |> do_build_type()
    with_children? = args |> Map.get(:children) |> length() > 0

    nested =
      parsers
      |> List.last()
      |> case do
        {:module, Maru.Params.Types.Map} when with_children? -> :map
        {:module, Maru.Params.Types.List} -> :list_of_map
        {:list, _} -> :list_of_single
        _ -> nil
      end

    func = do_build_parser(parsers, args)

    %{
      args: args,
      info: info,
      runtime:
        quote do
          %{unquote(runtime) | parser_func: unquote(func), nested: unquote(nested)}
        end
    }
  end

  defp do_build_param(:blank_func, %{args: args, info: info, runtime: runtime}, _env) do
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
      info: info,
      runtime:
        quote do
          %{unquote(runtime) | blank_func: unquote(func)}
        end
    }
  end

  defp do_build_param(:ignore_func, %{args: args, info: info, runtime: runtime}, %Macro.Env{
         module: module
       }) do
    given_condition = Module.get_attribute(module, :given_condition)

    func =
      if is_nil(given_condition) do
        quote do
          fn _ -> false end
        end
      else
        quote do
          fn result -> !unquote(given_condition).(result) end
        end
      end

    %{
      args: args,
      info: info,
      runtime:
        quote do
          %{unquote(runtime) | ignore_func: unquote(func)}
        end
    }
  end

  defp do_build_param(:children, %{args: args, info: info, runtime: runtime}, _env) do
    children_runtime = args |> Map.get(:children) |> Enum.map(&Map.get(&1, :runtime))

    %{
      args: args,
      info: info,
      runtime:
        quote do
          %{unquote(runtime) | children: unquote(children_runtime)}
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

  defp do_build_type({{:., _, [Access, :get]}, _, [List, nested]}) do
    do_build_type(List) ++ [{:list, do_build_type(nested)}]
  end

  defp do_build_type(type) do
    module = Module.concat(Maru.Params.Types, type)
    module.__info__(:functions)
    [{:module, module}]
  rescue
    UndefinedFunctionError ->
      raise TypeError, type: type, reason: "Undefined Type"
  end

  def do_build_parser(parsers, args) do
    value = quote do: value
    options = quote do: options

    block =
      Enum.reduce(parsers, value, fn
        {:list, nested}, ast ->
          nested_ast = do_build_parser(nested, args)

          quote do
            case unquote(ast) do
              {:ok, value} ->
                value
                |> Enum.map(fn item -> {:ok, item} end)
                |> Enum.map(fn ok_item -> unquote(nested_ast).(ok_item, unquote(options)) end)
                |> then(fn value -> {:ok, value} end)

              error ->
                error
            end
          end

        {:func, func}, ast ->
          quote do
            case unquote(ast) do
              {:ok, value} -> unquote(func).(value)
              error -> error
            end
          end

        {:module, module}, ast ->
          parser_args =
            args
            |> Map.take(module.parser_arguments())
            |> Macro.escape()

          validator_args =
            args
            |> Map.take(module.validator_arguments())
            |> Enum.map(&List.wrap/1)

          quote do
            case unquote(ast) do
              {:ok, value} ->
                options =
                  unquote(parser_args)
                  |> Map.get(:options, [])
                  |> Keyword.merge(unquote(options))

                args =
                  Enum.reduce(
                    unquote(validator_args),
                    unquote(module).parse(
                      unquote(ast),
                      Map.put(unquote(parser_args), :options, options)
                    ),
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
      fn unquote(value), unquote(options) ->
        unquote(block)
      end
    end
  end

  def push_param(param, %Macro.Env{module: module}) do
    params = Module.get_attribute(module, :params)
    Module.put_attribute(module, :params, params ++ List.wrap(param))
  end

  def put_params(params, %Macro.Env{module: module}) do
    Module.put_attribute(module, :params, params)
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
end
