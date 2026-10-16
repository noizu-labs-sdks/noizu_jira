# 〚🔧:𓤓𓜌𓈲𔎍〛 Noizu.Jira.Agile.Boards :: Jira Software boards.
defmodule Noizu.Jira.Agile.Boards do
  @moduledoc """
  Jira Software boards.

  Board CRUD and listing live under `/rest/agile/1.0`; board issues use the
  **enhanced** token-paginated endpoint `GET /rest/software/1.0/board/{boardId}/issue`
  because the offset equivalent is deprecated by Atlassian.

  """

  alias Noizu.Jira.{Pagination, Request}

  @agile "/rest/agile/1.0/board"
  @software "/rest/software/1.0/board"

  @doc """
  Lists boards (offset page: `{values, startAt, maxResults, total, isLast}`).

  """
  @spec list(Noizu.Jira.Client.t(), keyword()) :: {:ok, map()} | {:error, Noizu.Jira.Error.t()}
  # 〚🔧:𓋥𔍶𓈇𔂫〛 list :: Lists boards (offset page: `{values, startAt, maxResults, total, isLast}`).
  def list(client, opts \\ []) do
    params =
      Request.params(
        [
          start_at: :startAt,
          max_results: :maxResults,
          project_key: :projectKeyOrId,
          project_type_key: :projectTypeKey,
          name: :name
        ],
        opts
      )

    Request.request(client, :get, @agile, params: params)
  end

  @doc """
  Lazily streams boards. Raises `Noizu.Jira.Error` on page failure.

  """
  @spec stream(Noizu.Jira.Client.t(), keyword()) :: Enumerable.t()
  # 〚🔧:𔈄𔇝𓝭𓊶〛 stream :: Lazily streams boards.
  def stream(client, opts \\ []) do
    refetch = fn start -> list(client, Keyword.put(opts, :start_at, start)) end

    Pagination.stream(
      fn :first -> list(client, opts) end,
      &Map.get(&1, "values", []),
      fn page -> Pagination.offset_next(page, refetch) end
    )
  end

  @doc """
  Fetches a board by id.

  """
  @spec get(Noizu.Jira.Client.t(), pos_integer()) :: {:ok, map()} | {:error, Noizu.Jira.Error.t()}
  # 〚🔧:𔏁𓴌𓞡𓎶〛 get :: Fetches a board by id.
  def get(client, board_id),
    do: Request.request(client, :get, @agile <> "/" <> Request.encode_segment(board_id))

  @doc """
  Creates a board from a payload (`name`, `type`, `location`, `filterId`, ...).

  """
  @spec create(Noizu.Jira.Client.t(), map()) :: {:ok, map()} | {:error, Noizu.Jira.Error.t()}
  # 〚🔧:𓿀𓮺𓺨𓋗〛 create :: Creates a board from a payload (`name`, `type`, `location`, `filterId`, ...).
  def create(client, payload), do: Request.request(client, :post, @agile, json: payload)

  @doc "Deletes a board."
  @spec delete(Noizu.Jira.Client.t(), pos_integer()) ::
          {:ok, term()} | {:error, Noizu.Jira.Error.t()}
  # 〚🔧:𔘨𔅛𓳯𓁎〛 delete :: delete/2
  def delete(client, board_id),
    do: Request.request(client, :delete, @agile <> "/" <> Request.encode_segment(board_id))

  @doc """
  Lists a board's issues via the enhanced endpoint
  (`{issues, isLast, nextPageToken?}`).

  Options: `:max_results`, `:fields`, `:jql`, `:next_page_token`, `:validate_query`.
  """
  @spec issues(Noizu.Jira.Client.t(), pos_integer(), keyword()) ::
          {:ok, map()} | {:error, Noizu.Jira.Error.t()}
  # 〚🔧:𔓢𓯠𓃅𓲾〛 issues :: issues/3
  def issues(client, board_id, opts \\ []) do
    params =
      Request.params(
        [
          start_at: :startAt,
          max_results: :maxResults,
          fields: :fields,
          jql: :jql,
          next_page_token: :nextPageToken,
          validate_query: :validateQuery
        ],
        opts
      )

    Request.request(
      client,
      :get,
      @software <> "/" <> Request.encode_segment(board_id) <> "/issue",
      params: params
    )
  end

  @doc """
  Lazily streams a board's issues following `nextPageToken`. Raises `Noizu.Jira.Error` on page failure.

  """
  @spec issues_stream(Noizu.Jira.Client.t(), pos_integer(), keyword()) :: Enumerable.t()
  # 〚🔧:𔈉𓶇𓗚𓲻〛 issues_stream :: Lazily streams a board's issues following `nextPageToken`.
  def issues_stream(client, board_id, opts \\ []) do
    refetch = fn token -> issues(client, board_id, Keyword.put(opts, :next_page_token, token)) end

    Pagination.stream(
      fn :first -> issues(client, board_id, opts) end,
      &Map.get(&1, "issues", []),
      fn page -> Pagination.token_next(page, refetch) end
    )
  end
end
