defmodule HawkEx.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/Null-logic-0/hawk_ex"

  def project do
    [
      app: :hawk_ex,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:jason, "~> 1.4"},

      # Dev/Test only
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp description do
    ""
  end

  defp package do
    [
      name: :hawk_ex,
      version: @version,
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      source_url: @source_url,
      docs: docs()
    ]
  end

  defp docs do
    [
      main: "HawkEx",
      source_url: @source_url
    ]
  end
end
