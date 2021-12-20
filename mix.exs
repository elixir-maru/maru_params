defmodule MaruParams.MixProject do
  use Mix.Project

  def project do
    [
      app: :maru_params,
      version: "0.1.0",
      elixir: "~> 1.2",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    []
  end

  defp package do
    %{
      maintainers: ["Xiangrong Hao"],
      licenses: ["WTFPL"],
      links: %{"Github" => "https://github.com/elixir-maru/maru_params"}
    }
  end
end
