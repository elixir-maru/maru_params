# Maru Params
> A rebuild version of maru params parser which support phoenix framework.

[![Module Version](https://img.shields.io/hexpm/v/maru_params.svg)](https://hex.pm/packages/maru_params)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/maru_params/)
[![Total Download](https://img.shields.io/hexpm/dt/maru_params.svg)](https://hex.pm/packages/maru_params)
[![License](https://img.shields.io/hexpm/l/maru_params.svg)](https://github.com/falood/maru_params/blob/master/LICENSE)
[![Last Updated](https://img.shields.io/github/last-commit/falood/maru_params.svg)](https://github.com/falood/maru_params/commits/master)
[![CI](https://github.com/falood/maru_params/actions/workflows/ci.yml/badge.svg)](https://github.com/falood/maru_params/actions)

## Installation

```elixir
def deps do
  [
    {:maru_params, "~> 0.2"},

    # Optional dependency, you can also add your own json_library dependency
    # and config with `config :maru_params, json_library, YOUR_JSON_LIBRARY`.
    {:jason, "~> 1.3"},


    # Optional dependency to support `ecto_enum` validator for atom
    {:ecto, "~> 3.0"},

    # Optional dependency to support `Plug.File` type
    {:plug, "~> 1.12"},

    # Optional dependency to support `Decimal` float
    {:decimal, "~> 2.0"},

    ...
  ]
end
```

## Usage for Phoenix Controller

```Elixir
defmodule MyApp.MyController do
  use MyApp, :controller
  use Maru.Params.PhoenixController

  params :index do
    optional :id, String, regex: ~r/\d{7,10}/
    optional :name, String
  end

  def index(conn, params) do
    # the params here is parsed result
  end
end
```

## Buildin Types

### Atom

```elixir
requires :category, Atom
requires :role, Atom, values: [:role1, :role2], default: :role1
optional :fruit, Atom, ecto_enum: {User, :fruit}
```

### Base64

```elixir
requires :data, Base64, options: [padding: false]
requires :data, Base64, options: [padding: false]
```

### Boolean

```elixir
optional :save_card, Boolean
```

### DateTime

```elixir
requires :created, DateTime, format: {:unix, :second}
optional :created, DateTime, format: :unix, naive: true
optional :updated, DateTime, format: :iso8601, truncate: :second
```

### Float

```elixir
optional :pi, Float
optional :pi, Float, style: :decimals
```

### Integer

```elixir
optional :age, Integer
```

### Json
only available when json_library defined and loaded.

```elixir
requires :tags, Json |> String
requires :tags, Json |> List[Integer], max_length: 3
requires :data, Json |> Map, json_library_options: [strings: :copy] do
  optional :nested, String
end
```

### List

```elixir
requires :str, List, string_strategy: :codepoints
requires :chars, List, string_strategy: :charlist
requires :wrap, List, string_strategy: :wrap
requires :tags, List[String], default: ["N/A"]
requires :tags, List[String], max_length: 3
requires :tags, List[String], min_length: 1
requires :tags, List[String], length_range: 1..3
```

### Map

```elixir
requires :data, Map
```

### String

```elixir
config :maru_params, :regex_aliases, [
  uuid:  ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89AB][0-9a-f]{3}-[0-9a-f]{12}$/
]

optional :code, String, style: :upcase
optional :code, String, style: :downcase
optional :code, String, style: :camelcase, trim: " "
optional :code, String, style: :snakecase
optional :id, String, regex: ~r/^\d{7,10}$/
optional :uuid, String, regex: :uuid
optional :fruit, String, values: ["apple", "peach"]
```

## Pipeline Types

```elixir
requires :data, Base64
%{"data" => "MTE="} -> %{data: "11"}

requires :data, Base64 |> Integer
%{"data" => "MTE="} -> %{data: 11}

requires :data, Json
%{"data" => ~s|["1", "2", "3"]|} -> %{data: ["1", "2", "3"]}

requires :data, Json |> List[Integer]
%{"data" => ~s|["1", "2", "3"]|} -> %{data: [1, 2, 3]}

requires :data, Base64 |> List[Integer]
%{"data" => "WyIxIiwgIjIiLCAiMyJd"} -> %{data: [1, 2, 3]}

requires :data, List[Base64 |> Integer]
%{"data" => ["MTE=", "MTE="]} -> %{data: [11, 11]}
```

## Nested Types

```elixir
requires :data, Map do
  optional :id, Integer
  optional :name, String
end

%{"data" => %{"id" => "1", "name" => "X"}} -> %{data: %{id: 1, name: "X"}}

requires :data, List do
  optional :id, Integer
  optional :name, String
end

%{"data" => [%{"id" => "1", "name" => "X"}]} -> %{data: [%{id: 1, name: "X"}]}
```

## Default Values and Blank Values

```elixir
optional :a, String
%{} -> %{}
%{"a" => nil} -> %{}
%{"a" => ""} -> %{}

optional :a, String, keep_blank: true
%{"a" => nil} -> %{a: nil}
%{"a" => ""} -> %{a: ""}

optional :a, String, default: "test"
%{} -> %{a: "test"}

optional :a, String, keep_blank: true, default: "test"
%{"a" => nil} -> %{a: nil}
%{"a" => ""} -> %{a: ""}

requires :a, String
%{} -> # raise exception
%{"a" => nil} -> # raise exception
%{"a" => ""} -> # raise exception

requires :a, String, keep_blank: true
%{"a" => nil} -> %{a: nil}
%{"a" => ""} -> %{a: ""}

requires :a, String, default: "test"
%{} -> %{a: "test"}
%{"a" => nil} -> %{a: "test"}
%{"a" => ""} -> %{a: "test"}

requires :a, String, keep_blank: true, default: "test"
%{"a" => nil} -> %{a: nil}
%{"a" => ""} -> %{a: ""}
```

## Rename

```elixir
optional :a, String, source: :b

%{"b" => "1"} -> %{a: "1"}
```

## Evaluate Given

### only check params when another parameter is given

```elixir
optional :existed, Boolean

given :existed do
  requires :meta do
    requires :a, String
    requires :b, String
    requires :c, String
  end
end
```

### only check params when other params have specific values

```elixir
optional :a, String
optional :b, String

given a: "A", b: "B" do
  requires :c, Integer
end

given a: "AA", b: "BB" do
  requires :c, String
end
```

### only check params when the particular condition is met

```elixir
requires :age, Integer

given fn %{age: age} -> age < 18 end do
  requires :id, String
end
```
