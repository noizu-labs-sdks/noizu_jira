defmodule Noizu.Jira.Statuses do
  @moduledoc """
  Statuses (platform v3).

  `list/1` uses the legacy flat `GET /rest/api/3/status` array;
  `search/2`/`stream/2` use the paginated `GET /rest/api/3/statuses/search`.

  〚📦:𓱓𔖮𓥓𓚞〛 Noizu.Jira.Statuses :: Statuses (platform v3).
  """

  alias Noizu.Jira.{Pagination, Request}

  @doc """
  Lists all statuses (legacy flat array).

  〚🔧:𐦅𔙿𓖃𓥉〛 list :: Lists all statuses (legacy flat array).
  """
  @spec list(Noizu.Jira.Client.t()) :: {:ok, [map()]} | {:error, Noizu.Jira.Error.t()}
  def list(client), do: Request.request(client, :get, "/rest/api/3/status")

  @doc """
  Searches statuses (offset page: `{values, startAt, maxResults, total, isLast}`).

  〚🔧:𔘻𓅤𓊒𓣬〛 search :: Searches statuses (offset page: `{values, startAt, maxResults, total, isLast}`).
  """
  @spec search(Noizu.Jira.Client.t(), keyword()) :: {:ok, map()} | {:error, Noizu.Jira.Error.t()}
  def search(client, opts \\ []) do
    params =
      Request.params(
        [project_id: :projectId, start_at: :startAt, max_results: :maxResults, expand: :expand],
        opts
      )

    Request.request(client, :get, "/rest/api/3/statuses/search", params: params)
  end

  @doc """
  Lazily streams statuses. Raises `Noizu.Jira.Error` on page failure.

  〚🔧:𓛛𓎅𓡶𓼷〛 stream :: Lazily streams statuses.
  """
  @spec stream(Noizu.Jira.Client.t(), keyword()) :: Enumerable.t()
  def stream(client, opts \\ []) do
    refetch = fn start -> search(client, Keyword.put(opts, :start_at, start)) end

    Pagination.stream(
      fn :first -> search(client, opts) end,
      &Map.get(&1, "values", []),
      fn page -> Pagination.offset_next(page, refetch) end
    )
  end
end
