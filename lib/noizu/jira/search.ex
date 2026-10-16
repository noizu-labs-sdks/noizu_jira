defmodule Noizu.Jira.Search do
  @moduledoc """
  JQL issue search via the replacement endpoint `POST /rest/api/3/search/jql`
  (the legacy `GET/POST /search` is deprecated and being removed by Atlassian).

  Responses are `{issues, isLast, nextPageToken?}`; `stream/3` walks
  `nextPageToken` lazily.

  〚📦:𓥯𓢷𓩤𓣸〛 Noizu.Jira.Search :: JQL issue search via the replacement endpoint `POST /rest/api/3/search/jql`
  """

  alias Noizu.Jira.{Pagination, Request}

  @path "/rest/api/3/search/jql"

  @doc """
  Searches issues with JQL.

  Options map to body fields: `:max_results`, `:next_page_token`, `:fields`
  (list of field ids), `:fields_by_keys`, `:properties`, `:validate_query`.

      {:ok, page} =
        Noizu.Jira.Search.search(client, "project = PROJ ORDER BY created DESC",
          max_results: 50,
          fields: ["summary", "status"]
        )
  """
  @spec search(Noizu.Jira.Client.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, Noizu.Jira.Error.t()}
  @doc """
  How: takes `client`, `jql`, `opts`

  〚🔧:𔉬𔙛𓲕𓕿〛 search :: search/3
  """
  def search(client, jql, opts \\ []) do
    body =
      %{"jql" => jql}
      |> maybe_put("maxResults", opts[:max_results])
      |> maybe_put("nextPageToken", opts[:next_page_token])
      |> maybe_put("fields", opts[:fields])
      |> maybe_put("fieldsByKeys", opts[:fields_by_keys])
      |> maybe_put("properties", opts[:properties])
      |> maybe_put("validateQuery", opts[:validate_query])

    Request.request(client, :post, @path, json: body)
  end

  @doc """
  Lazily streams issues across all pages, following `nextPageToken`.

  Raises `Noizu.Jira.Error` if a page fetch fails. `:next_page_token` has no
  meaning here (streaming starts at the first page).

  〚🔧:𔉫𓈢𓔒𓺌〛 stream :: Lazily streams issues across all pages, following `nextPageToken`.
  """
  @spec stream(Noizu.Jira.Client.t(), String.t(), keyword()) :: Enumerable.t()
  def stream(client, jql, opts \\ []) do
    refetch = fn token -> search(client, jql, Keyword.put(opts, :next_page_token, token)) end

    Pagination.stream(
      fn :first -> search(client, jql, opts) end,
      &Map.get(&1, "issues", []),
      fn page -> Pagination.token_next(page, refetch) end
    )
  end

  @doc """
  Approximate result count for a JQL query (no index scan). Returns `{:ok, %{\"count\" => n}}`.

  〚🔧:𓣿𓩐𓈌𓖁〛 count :: Approximate result count for a JQL query (no index scan).
  """
  @spec count(Noizu.Jira.Client.t(), String.t()) :: {:ok, map()} | {:error, Noizu.Jira.Error.t()}
  def count(client, jql) do
    Request.request(client, :post, "/rest/api/3/search/approximate-count", json: %{"jql" => jql})
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
