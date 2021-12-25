# Maru Params
> A rebuild version of maru params parser which support phoenix framework.

## Installation

```elixir
def deps do
  [
    {:maru_params, "~> 0.1"},

    # Optional dependency, you can also add your own json_library dependency
    # and config with `config :maru_params, json_library, YOUR_JSON_LIBRARY`.
    {:jason, "~> 1.3"}
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
optional :code, String, style: :upcase
optional :code, String, style: :downcase
optional :code, String, style: :camelcase
optional :code, String, style: :snakecase
optional :id, String, regex: ~r/\d{7,10}/
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
%{a: null} -> %{}
%{a: ""} -> %{}

optional :a, String, keep_blank: true
%{a: null} -> %{a: null}
%{a: ""} -> %{a: ""}

optional :a, String, default: "test"
%{} -> %{a: "test"}

optional :a, String, keep_blank: true, default: "test"
%{a: null} -> %{a: null}
%{a: ""} -> %{a: ""}

requires :a, String
%{} -> # raise exception
%{a: null} -> # raise exception
%{a: ""} -> # raise exception

requires :a, String, keep_blank: true
%{a: null} -> %{a: null}
%{a: ""} -> %{a: ""}

requires :a, String, default: "test"
%{} -> %{a: "test"}
%{a: null} -> %{a: "test"}

requires :a, String, keep_blank: true, default: "test"
%{a: null} -> %{a: null}
%{a: ""} -> %{a: ""}
```

## Rename

```elixir
optional :a, String, source: "b"

%{b: "1"} -> %{a: "1"}
```
