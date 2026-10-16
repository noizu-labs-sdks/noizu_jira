defmodule Noizu.Jira.Agile.Sprints do
  @moduledoc """
  Jira Software sprints (`/rest/agile/1.0`). Sprint issues use offset pagination
  (`{issues, startAt, maxResults, total, isLast}`).

  〚📦:𓃘𓒎𓴚𔘧〛 Noizu.Jira.Agile.Sprints :: Jira Software sprints (`/rest/agile/1.0`).
  """

  alias Noizu.Jira.{Pagination, Request}

  @base "/rest/agile/1.0/sprint"

  @doc """
  Fetches a sprint by id.

  〚🔧:𔆠𓽣𓍒𓢋〛 get :: Fetches a sprint by id.
  """
  @spec get(Noizu.Jira.Client.t(), pos_integer()) :: {:ok, map()} | {:error, Noizu.Jira.Error.t()}
  def get(client, sprint_id),
    do: Request.request(client, :get, @base <> "/" <> Request.encode_segment(sprint_id))

  @doc """
  Creates a sprint from a payload (`name`, `startDate`, `endDate`, `originBoardId`, ...).

  〚🔧:𓻰𓦥𓛑𓖙〛 create :: Creates a sprint from a payload (`name`, `startDate`, `endDate`, `originBoardId`, ...).
  """
  @spec create(Noizu.Jira.Client.t(), map()) :: {:ok, map()} | {:error, Noizu.Jira.Error.t()}
  def create(client, payload), do: Request.request(client, :post, @base, json: payload)

  @doc "Updates a sprint."
  @spec update(Noizu.Jira.Client.t(), pos_integer(), map()) ::
          {:ok, map()} | {:error, Noizu.Jira.Error.t()}
  @doc """
  How: takes `client`, `sprint_id`, `payload`

  〚🔧:𓤄𓦚𔎯𓷀〛 update :: update/3
  """
  def update(client, sprint_id, payload) do
    Request.request(client, :put, @base <> "/" <> Request.encode_segment(sprint_id),
      json: payload
    )
  end

  @doc "Deletes a sprint."
  @spec delete(Noizu.Jira.Client.t(), pos_integer()) ::
          {:ok, term()} | {:error, Noizu.Jira.Error.t()}
  @doc """
  How: takes `client`, `sprint_id`

  〚🔧:𓃂𓴂𔗰𔆲〛 delete :: delete/2
  """
  def delete(client, sprint_id),
    do: Request.request(client, :delete, @base <> "/" <> Request.encode_segment(sprint_id))

  @doc "Lists a sprint's issues (offset page). Options: `:start_at`, `:max_results`, `:jql`, `:fields`."
  @spec issues(Noizu.Jira.Client.t(), pos_integer(), keyword()) ::
          {:ok, map()} | {:error, Noizu.Jira.Error.t()}
  @doc """
  How: takes `client`, `sprint_id`, `opts`

  〚🔧:𔑚𓩱𓖞𔁓〛 issues :: issues/3
  """
  def issues(client, sprint_id, opts \\ []) do
    params =
      Request.params(
        [start_at: :startAt, max_results: :maxResults, jql: :jql, fields: :fields],
        opts
      )

    Request.request(client, :get, @base <> "/" <> Request.encode_segment(sprint_id) <> "/issue",
      params: params
    )
  end

  @doc """
  Lazily streams a sprint's issues. Raises `Noizu.Jira.Error` on page failure.

  〚🔧:𔕀𓍮𓞁𓵬〛 issues_stream :: Lazily streams a sprint's issues.
  """
  @spec issues_stream(Noizu.Jira.Client.t(), pos_integer(), keyword()) :: Enumerable.t()
  def issues_stream(client, sprint_id, opts \\ []) do
    refetch = fn start -> issues(client, sprint_id, Keyword.put(opts, :start_at, start)) end

    Pagination.stream(
      fn :first -> issues(client, sprint_id, opts) end,
      &Map.get(&1, "issues", []),
      fn page -> Pagination.offset_next(page, refetch, &Map.get(&1, "issues", [])) end
    )
  end
end
