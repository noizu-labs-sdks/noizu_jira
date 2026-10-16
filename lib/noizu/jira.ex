defmodule Noizu.Jira do
  @moduledoc """
  Elixir client for the Jira Cloud REST API (platform v3 and the Jira Software agile API).

  Build a [`Noizu.Jira.Client`](`Noizu.Jira.Client`) and pass it explicitly to every
  call. Functions return `{:ok, body}` or `{:error, %Noizu.Jira.Error{}}`; bodies are
  decoded JSON maps. A lazy `*_stream` variant is provided for every paginated list
  operation; streams raise `Noizu.Jira.Error` on mid-stream failures.

      client =
        Noizu.Jira.Client.new(
          auth: {:basic, "you@example.com", System.fetch_env!("JIRA_API_TOKEN")},
          site: "example.atlassian.net"
        )

      {:ok, issue} = Noizu.Jira.Issues.get(client, "PROJ-123")

      Noizu.Jira.Search.stream(client, "project = PROJ ORDER BY created DESC")
      |> Stream.map(& &1["key"])
      |> Enum.take(100)

  Auth modes, endpoint inventory, pagination semantics, the error model, and the
  retry policy are specified in `docs/API-CONTRACT.md` in the package root.

  〚📦:𓗋𔀚𓌤𔄏〛 Noizu.Jira :: Elixir client for the Jira Cloud REST API (platform v3 and the Jira Software agile API).
  """
end
