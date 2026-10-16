defmodule Noizu.Jira.Projects do
  @moduledoc """
  Project lookup (platform v3, offset pagination).

  〚📦:𓒍𔌊𓩛𔃂〛 Noizu.Jira.Projects :: Project lookup (platform v3, offset pagination).
  """

  alias Noizu.Jira.{Pagination, Request}

  @doc """
  Searches projects (offset page: `{values, startAt, maxResults, total, isLast}`).

  〚🔧:𓚵𓣆𔋃𓶜〛 search :: Searches projects (offset page: `{values, startAt, maxResults, total, isLast}`).
  """
  @spec search(Noizu.Jira.Client.t(), keyword()) :: {:ok, map()} | {:error, Noizu.Jira.Error.t()}
  def search(client, opts \\ []) do
    params =
      Request.params(
        [
          {:start_at, :startAt},
          {:max_results, :maxResults},
          {:query, :query},
          {:keys, :keys, :multi},
          {:type_key, :typeKey},
          {:category_id, :categoryId},
          {:action, :action},
          {:expand, :expand},
          {:status, :status, :multi}
        ],
        opts
      )

    Request.request(client, :get, "/rest/api/3/project/search", params: params)
  end

  @doc """
  Lazily streams projects. Raises `Noizu.Jira.Error` on page failure.

  〚🔧:𓣜𓄘𓗧𔌷〛 stream :: Lazily streams projects.
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

  @doc "Fetches a project by key or id. Options: `:expand`."
  @spec get(Noizu.Jira.Client.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, Noizu.Jira.Error.t()}
  @doc """
  How: takes `client`, `project_key_or_id`, `opts`

  〚🔧:𓱌𓭠𔒨𓮚〛 get :: get/3
  """
  def get(client, project_key_or_id, opts \\ []) do
    params = Request.params([expand: :expand], opts)

    Request.request(
      client,
      :get,
      "/rest/api/3/project/" <> Request.encode_segment(project_key_or_id),
      params: params
    )
  end
end
