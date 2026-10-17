defmodule Noizu.Jira.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/noizu-labs-sdks/noizu_jira"
  @description "Elixir client for the Jira Cloud REST API v3 and the Jira Software agile API (basic auth and OAuth 2.0 3LO)."

  def project do
    [
      app: :noizu_jira,
      version: @version,
      description: @description,
      name: "Noizu.Jira",
      source_url: @source_url,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:req, "~> 0.7"},
      {:jason, "~> 1.4"},
      {:plug, "~> 1.16", only: :test},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "docs/API-CONTRACT.md",
        "docs/PROJ-LAYOUT.md",
        "docs/layout/lib.md",
        "docs/layout/test.md",
        "docs/PROJ-ARCH.md",
        "docs/arch/request-pipeline.md",
        "docs/arch/streaming.md",
        "docs/THREAT-MODEL.md",
        "docs/threats/credentials.md",
        "docs/threats/url-construction.md",
        "docs/threats/input-surfaces.md",
        "docs/threats/network-retry.md",
        "docs/threats/supply-chain.md",
        "CHANGELOG.md"
      ],
      groups_for_modules: [
        Resources: [
          Noizu.Jira.Issues,
          Noizu.Jira.Search,
          Noizu.Jira.Transitions,
          Noizu.Jira.Comments,
          Noizu.Jira.Worklogs,
          Noizu.Jira.Attachments,
          Noizu.Jira.IssueLinks,
          Noizu.Jira.Projects,
          Noizu.Jira.Users,
          Noizu.Jira.Fields,
          Noizu.Jira.IssueTypes,
          Noizu.Jira.Statuses
        ],
        Agile: [Noizu.Jira.Agile.Boards, Noizu.Jira.Agile.Sprints],
        Core: [Noizu.Jira.Client, Noizu.Jira.Error, Noizu.Jira.ADF]
      ]
    ]
  end

  defp package do
    [
      name: "noizu_jira",
      files: ["lib", "mix.exs", "README.md", "LICENSE", "CHANGELOG.md", "docs"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url, "Changelog" => @source_url <> "/blob/main/CHANGELOG.md"}
    ]
  end
end
