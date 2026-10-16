# 〚🔧:𓕫𓥥𓐆𓋵〛 Noizu.Jira.Users :: User lookup (platform v3).
defmodule Noizu.Jira.Users do
  @moduledoc """
  User lookup (platform v3). `search/3` returns a raw array (this endpoint does
  not use the pagination envelope); `stream/3` pages it by `startAt`.

  """

  alias Noizu.Jira.{Pagination, Request}

  @doc """
  Returns the current user.

  """
  @spec me(Noizu.Jira.Client.t()) :: {:ok, map()} | {:error, Noizu.Jira.Error.t()}
  # 〚🔧:𓷁𓔷𓬌𓤞〛 me :: Returns the current user.
  def me(client), do: Request.request(client, :get, "/rest/api/3/myself")

  @doc """
  Fetches a user. Options: `:account_id` (preferred), `:key`/`:username` (legacy), `:expand`.

  """
  @spec get(Noizu.Jira.Client.t(), keyword()) :: {:ok, map()} | {:error, Noizu.Jira.Error.t()}
  # 〚🔧:𓹦𔋚𓎃𔅮〛 get :: Fetches a user.
  def get(client, opts \\ []) do
    params =
      Request.params(
        [account_id: :accountId, key: :key, username: :username, expand: :expand],
        opts
      )

    Request.request(client, :get, "/rest/api/3/user", params: params)
  end

  @doc """
  Finds users matching `query` (`name`/`email`). Returns a bare list.

  Options: `:start_at`, `:max_results`.
  """
  @spec search(Noizu.Jira.Client.t(), String.t(), keyword()) ::
          {:ok, [map()]} | {:error, Noizu.Jira.Error.t()}
  # 〚🔧:𓏨𓕟𓠘𓪹〛 search :: search/3
  def search(client, query, opts \\ []) do
    base_params = Request.params([start_at: :startAt, max_results: :maxResults], opts)
    params = base_params ++ [{"query", query}]

    Request.request(client, :get, "/rest/api/3/user/search", params: params)
  end

  @doc """
  Lazily streams users across pages. Stops when a page is empty or shorter than
  `:max_results`. Raises `Noizu.Jira.Error` on page failure.

  """
  @spec stream(Noizu.Jira.Client.t(), String.t(), keyword()) :: Enumerable.t()
  # 〚🔧:𓲤𓈜𓇉𓆛〛 stream :: Lazily streams users across pages.
  def stream(client, query, opts \\ []) do
    start_at = opts[:start_at] || 0
    refetch = fn next -> search(client, query, Keyword.put(opts, :start_at, next)) end

    Pagination.stream(
      fn :first -> search(client, query, opts) end,
      & &1,
      fn items ->
        Pagination.array_next(items, refetch, start_at + length(items), opts[:max_results])
      end
    )
  end
end
