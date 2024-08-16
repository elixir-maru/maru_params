defmodule MaruParams.MixProject do
  use Mix.Project

  def project do
    [
      app: :maru_params,
      version: "0.2.10",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "A rebuild version maru params parser which support phoenix.",
      package: package(),
      docs: [
        extras: ["README.md"],
        main: "readme"
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:decimal, "~> 1.0 or ~> 2.0", optional: true},
      {:plug, "~> 1.10", optional: true},
      {:jason, "~> 1.0", optional: true},
      {:ex_doc, "~> 0.29", only: :docs}
    ]
  end

  defp package do
    %{
      maintainers: ["Xiangrong Hao"],
      licenses: ["WTFPL"],
      links: %{"Github" => "https://github.com/elixir-maru/maru_params"}
    }
  end
end
