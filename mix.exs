defmodule Whistle.MixProject do
  use Mix.Project

  def project do
    [
      app: :whistle,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package()
    ]
  end

  defp package() do
    [
      name: "whistle",
      files: ["lib", "mix.exs", "README.md", "LICENSE.md"],
      maintainers: ["Mohamed Boudra"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/boudra/whistle"}
    ]
  end

  defp description() do
    "whistle"
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :plug_cowboy]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug, "~> 1.7"},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.0"},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end
end
