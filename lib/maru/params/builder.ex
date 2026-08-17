defmodule Maru.Params.Builder do
  alias Maru.Params.{Runtime, TypeError}

  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)
      @params []
      @given_condition []
      @maru_path []
      @maru_includes []
      @maru_given_pairs []
    end
  end

  for {method, required} <- [{:optional, false}, {:requires, true}] do
    defmacro unquote(method)(name, do: block) do
      args = Macro.escape(%{__name__: name, __type__: Map, __required__: unquote(required)})

      quote do
        given_condition = @given_condition
        @given_condition []
        params = unquote(__MODULE__).pop_params(__ENV__)
        unquote(__MODULE__).push_path(unquote(name), __ENV__)
        unquote(block)
        unquote(__MODULE__).pop_path(__ENV__)
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
        @given_condition []
        params = unquote(__MODULE__).pop_params(__ENV__)
        unquote(__MODULE__).push_path(unquote(name), __ENV__)
        unquote(block)
        unquote(__MODULE__).pop_path(__ENV__)
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
        @given_condition []
        params = unquote(__MODULE__).pop_params(__ENV__)
        unquote(__MODULE__).push_path(unquote(name), __ENV__)
        unquote(block)
        unquote(__MODULE__).pop_path(__ENV__)
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

  # `@given_condition` is a stack of quoted conditions: entering a `given`
  # pushes its condition, leaving pops it, so nested `given`s compose and a
  # param only runs when every enclosing condition holds.
  defmacro given(name, do: block) when is_atom(name) do
    func =
      quote do
        fn result -> Map.has_key?(result, unquote(name)) end
      end

    quote do
      unquote(__MODULE__).check_given_keys([unquote(name)], __ENV__)
      @given_condition [unquote(Macro.escape(func)) | @given_condition]
      unquote(block)
      @given_condition tl(@given_condition)
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

    keys = for {key, _value} <- kv_pair, is_atom(key), do: key

    pairs =
      for {key, value} <- kv_pair, is_atom(key), Macro.quoted_literal?(value), do: {key, value}

    quote do
      unquote(__MODULE__).check_given_keys(unquote(keys), __ENV__)
      @maru_given_pairs @maru_given_pairs ++ unquote(Macro.escape(pairs))
      @given_condition [unquote(Macro.escape(func)) | @given_condition]
      unquote(block)
      @given_condition tl(@given_condition)
    end
  end

  defmacro given({:fn, _, _} = func, do: block) do
    quote do
      @given_condition [unquote(Macro.escape(func)) | @given_condition]
      unquote(block)
      @given_condition tl(@given_condition)
    end
  end

  defmacro given({:&, _, _} = func, do: block) do
    quote do
      @given_condition [unquote(Macro.escape(func)) | @given_condition]
      unquote(block)
      @given_condition tl(@given_condition)
    end
  end

  @doc false
  # Runs while the module body is evaluated, so `@params` holds exactly the
  # params declared before this `given` at the current level. A condition reads
  # the result of its own level, which is built in declaration order, so a key
  # not declared before the block (and not in `reads:`, which names fields of
  # the enclosing level) can never be true.
  def check_given_keys(keys, %Macro.Env{module: module} = env) do
    params = Module.get_attribute(module, :params)
    declared = for %{info: info} <- params, do: Keyword.get(info, :name)
    include? = Enum.any?(params, &Map.has_key?(&1, :include))

    # `reads:` names live in the level the schema is included into, which the
    # schema's top level is spliced into - a nested level can never see them
    reads =
      case Module.get_attribute(module, :maru_path) do
        [] -> Module.get_attribute(module, :maru_reads) || []
        _nested -> []
      end

    case keys -- (declared ++ reads) do
      [] ->
        :ok

      _missing when include? ->
        # a preceding include may declare them, unknown at compile time
        :ok

      missing ->
        raise CompileError,
          file: env.file,
          line: env.line,
          description:
            "given condition reads #{inspect(missing)} which is not declared before this block at the same level"
    end
  end

  @doc """
  Merge the params blocks of a `Maru.Params.Schema` module into the current level.

  The referenced module is only called inside a function body, so it is a runtime
  dependency: editing it does not recompile the modules including it. For the same
  reason nothing about it can be checked at compile time, use
  `Maru.Params.verify_all/1` at boot or in a test instead.

  ## Examples
      include MyApp.Params.Address
      include MyApp.Params.Address, only: :basic
      include MyApp.Params.Address, only: [:basic, :full]
      include MyApp.Params.Address, except: [:full]
  """
  defmacro include(module, opts \\ []) do
    case module do
      {:__aliases__, _, _} ->
        :ok

      module when is_atom(module) ->
        :ok

      list when is_list(list) ->
        raise CompileError,
          file: __CALLER__.file,
          line: __CALLER__.line,
          description: "include takes one module; write one include per module"

      _ ->
        raise CompileError,
          file: __CALLER__.file,
          line: __CALLER__.line,
          description: "include takes one literal module, got: #{Macro.to_string(module)}"
    end

    # literal only: evaluating anything else in the module body would create
    # a compile time dependency on whatever the expression calls
    unless valid_include_opts?(opts) do
      raise CompileError,
        file: __CALLER__.file,
        line: __CALLER__.line,
        description:
          "include options must be literal :only / :except with atom block names, " <>
            "got: #{Macro.to_string(opts)}"
    end

    if Keyword.has_key?(opts, :only) and Keyword.has_key?(opts, :except) do
      raise CompileError,
        file: __CALLER__.file,
        line: __CALLER__.line,
        description: ":only and :except are in conflict!"
    end

    # `module` stays unexpanded alias AST here and is only ever spliced into
    # function bodies, so include never creates a compile time dependency on it.
    quote do
      unquote(__MODULE__).build_include(
        unquote(Macro.escape(module)),
        unquote(Macro.escape(opts)),
        __ENV__
      )
      |> unquote(__MODULE__).push_param(__ENV__)
    end
  end

  defp valid_include_opts?(opts) do
    Keyword.keyword?(opts) and
      Enum.all?(opts, fn {key, value} ->
        key in [:only, :except] and value |> List.wrap() |> Enum.all?(&is_atom/1)
      end)
  end

  @doc false
  def build_include(module, opts, %Macro.Env{module: caller} = env) do
    record_include(module, opts, env)

    runtime =
      quote do
        Maru.Params.Schema.resolve(unquote(module), unquote(Macro.escape(opts)))
      end

    runtime =
      case Module.get_attribute(caller, :given_condition) do
        [] ->
          runtime

        conditions ->
          quote do
            Maru.Params.Runtime.under(unquote(runtime), unquote(ignore_func_ast(conditions)))
          end
      end

    %{include: true, runtime: runtime}
  end

  defp record_include(module, opts, %Macro.Env{module: caller}) do
    preceding =
      for param <- Module.get_attribute(caller, :params), not Map.has_key?(param, :include) do
        param |> Map.get(:info) |> Keyword.get(:name)
      end

    include = %{
      path: caller |> Module.get_attribute(:maru_path) |> Enum.reverse(),
      module: module,
      opts: opts,
      preceding: preceding
    }

    includes = Module.get_attribute(caller, :maru_includes)
    Module.put_attribute(caller, :maru_includes, includes ++ [include])
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
        {true, _} -> {:default, args[:default]}
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
    func = module |> Module.get_attribute(:given_condition) |> ignore_func_ast()

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
    children_runtime = args |> Map.get(:children) |> runtime_list()

    %{
      args: args,
      info: info,
      runtime:
        quote do
          %{unquote(runtime) | children: unquote(children_runtime)}
        end
    }
  end

  defp ignore_func_ast([]) do
    quote do
      fn _ -> false end
    end
  end

  defp ignore_func_ast([condition]) do
    quote do
      fn result -> !unquote(condition).(result) end
    end
  end

  defp ignore_func_ast(conditions) do
    # the stack is inner-first; run outer-first so an inner condition is only
    # evaluated when every outer one already holds, same as `outer and inner`
    conditions = Enum.reverse(conditions)

    quote do
      fn result -> not Enum.all?(unquote(conditions), fn condition -> condition.(result) end) end
    end
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
    cond do
      type_module?(type) ->
        [{:module, type}]

      type_module?(Module.concat(Maru.Params.Types, type)) ->
        [{:module, Module.concat(Maru.Params.Types, type)}]

      true ->
        raise TypeError, type: type, reason: "Undefined Type"
    end
  end

  # a type is either the named module itself or one under the
  # Maru.Params.Types namespace
  defp type_module?(module) do
    match?({:module, _}, Code.ensure_compiled(module)) and
      function_exported?(module, :parse, 2) and
      function_exported?(module, :parser_arguments, 0)
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
                |> Enum.with_index()
                |> Enum.map(fn {ok_item, index} ->
                  Runtime.with_path(index, fn ->
                    unquote(nested_ast).(ok_item, unquote(options))
                  end)
                end)
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
          parser_args = Map.take(args, module.parser_arguments())
          preset_options = Map.get(parser_args, :options, [])
          parser_args_ast = Macro.escape(parser_args)
          preset_options_ast = Macro.escape(preset_options)

          validator_args =
            args
            |> Map.take(module.validator_arguments())
            |> Enum.map(&List.wrap/1)

          quote do
            case unquote(ast) do
              {:ok, value} ->
                options = Keyword.merge(unquote(preset_options_ast), unquote(options))

                args =
                  Enum.reduce(
                    unquote(validator_args),
                    unquote(module).parse(
                      value,
                      Map.put(unquote(parser_args_ast), :options, options)
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

  # Build the quoted params list of a level. Consecutive ordinary params keep
  # being a list literal, an include contributes its resolved list at runtime:
  # [p1, p2, include, p3] becomes Enum.concat([[ast1, ast2], include_ast, [ast3]])
  @doc false
  def runtime_list(params) do
    if Enum.any?(params, &Map.has_key?(&1, :include)) do
      segments =
        params
        |> Enum.chunk_by(&Map.has_key?(&1, :include))
        |> Enum.flat_map(fn
          [%{include: _} | _] = includes -> Enum.map(includes, &Map.get(&1, :runtime))
          params -> [Enum.map(params, &Map.get(&1, :runtime))]
        end)

      quote do
        Enum.concat(unquote(segments))
      end
    else
      Enum.map(params, &Map.get(&1, :runtime))
    end
  end

  # Quoted `__maru_includes__/0,1` and `__maru_given__/1` definitions for a list
  # of `{name, block}` where block comes from `pop_block/1`. The recorded module
  # of an include is still alias AST and only expands here, inside function bodies.
  @doc false
  def metadata_ast(blocks) do
    names = Enum.map(blocks, fn {name, _block} -> name end)

    includes =
      Enum.map(blocks, fn {name, block} ->
        records =
          Enum.map(block.includes, fn record ->
            {:%{}, [],
             [
               path: record.path,
               module: record.module,
               opts: record.opts,
               preceding: record.preceding
             ]}
          end)

        quote do
          def __maru_includes__(unquote(name)), do: unquote(records)
        end
      end)

    given =
      Enum.map(blocks, fn {name, block} ->
        quote do
          def __maru_given__(unquote(name)), do: unquote(block.given)
        end
      end)

    quote do
      def __maru_includes__, do: unquote(names)
      unquote(includes)
      unquote(given)
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

  @doc false
  def pop_block(%Macro.Env{module: module} = env) do
    block = %{
      params: pop_params(env),
      includes: Module.get_attribute(module, :maru_includes),
      given: Module.get_attribute(module, :maru_given_pairs)
    }

    Module.put_attribute(module, :maru_includes, [])
    Module.put_attribute(module, :maru_given_pairs, [])
    block
  end

  @doc false
  def push_path(name, %Macro.Env{module: module}) do
    Module.put_attribute(module, :maru_path, [name | Module.get_attribute(module, :maru_path)])
  end

  @doc false
  def pop_path(%Macro.Env{module: module}) do
    [_ | path] = Module.get_attribute(module, :maru_path)
    Module.put_attribute(module, :maru_path, path)
  end

  def expand_alias(ast, caller) do
    Macro.prewalk(ast, fn
      {:__aliases__, _, _} = module -> Macro.expand(module, caller)
      other -> other
    end)
  end
end
