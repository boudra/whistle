defmodule Whistle.MixProject do
  use Mix.Project

  def project do
    [
      app: :whistle,
      version: "0.1.0",
      elixir: "~> 1.7",
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      start_permanent: Mix.env() == :prod,
      docs: docs(),
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

  defp docs() do
    [
      main: "readme",
      extras: extras()
    ]
  end

  defp extras() do
    [
      "README.md",
      "docs/phoenix.md",
      "docs/setup.md",
      "docs/distributed.md"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: [],
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug, "~> 1.7"},
      {:nimble_parsec, "~> 0.5.0"},

      # Optional dependencies
      {:jason, "~> 1.0", optional: true},
      {:plug_cowboy, "~> 2.0", optional: true},
      {:ex_doc, "~> 0.19.0", only: :dev, runtime: false},
      {:inch_ex, github: "rrrene/inch_ex", only: [:dev, :test]},
      {:excoveralls, "~> 0.8", only: :test}
    ]
  end
end
