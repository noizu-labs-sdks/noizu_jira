# 〚🔧:𔗩𓭼𔄜𓂾〛 Noizu.Jira.Comments :: Issue comments (platform v3, offset pagination).
defmodule Noizu.Jira.Comments do
  @moduledoc """
  Issue comments (platform v3, offset pagination).

  Comment bodies are ADF; binaries passed to `add/4` and `update/5` are wrapped
  with [`Noizu.Jira.ADF.doc/1`](`Noizu.Jira.ADF`).

  """

  alias Noizu.Jira.{ADF, Pagination, Request}

  defp base(issue_id_or_key),
    do: "/rest/api/3/issue/" <> Request.encode_segment(issue_id_or_key) <> "/comment"

  @doc "Lists comments (offset page: `{comments, startAt, maxResults, total, isLast}`)."
  @spec list(Noizu.Jira.Client.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, Noizu.Jira.Error.t()}
  # 〚🔧:𔈵𓙖𓉙𓖪〛 list :: list/3
  def list(client, issue_id_or_key, opts \\ []) do
    params =
      Request.params(
        [start_at: :startAt, max_results: :maxResults, expand: :expand, order_by: :orderBy],
        opts
      )

    Request.request(client, :get, base(issue_id_or_key), params: params)
  end

  @doc """
  Lazily streams every comment. Raises `Noizu.Jira.Error` on page failure.

  """
  @spec stream(Noizu.Jira.Client.t(), String.t(), keyword()) :: Enumerable.t()
  # 〚🔧:𔗢𔈇𓞧𓭖〛 stream :: Lazily streams every comment.
  def stream(client, issue_id_or_key, opts \\ []) do
    refetch = fn start -> list(client, issue_id_or_key, Keyword.put(opts, :start_at, start)) end

    Pagination.stream(
      fn :first -> list(client, issue_id_or_key, opts) end,
      &Map.get(&1, "comments", []),
      fn page ->
        Pagination.offset_next(page, refetch, &Map.get(&1, "comments", []))
      end
    )
  end

  @doc "Adds a comment; plain text is wrapped in ADF. Options: `:expand`."
  @spec add(Noizu.Jira.Client.t(), String.t(), String.t() | map(), keyword()) ::
          {:ok, map()} | {:error, Noizu.Jira.Error.t()}
  # 〚🔧:𓠄𓹝𓾸𓳖〛 add :: add/4
  def add(client, issue_id_or_key, body, opts \\ []) do
    params = Request.params([expand: :expand], opts)

    Request.request(client, :post, base(issue_id_or_key),
      json: %{"body" => ADF.doc(body)},
      params: params
    )
  end

  @doc "Fetches one comment. Option: `:expand`."
  @spec get(Noizu.Jira.Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, Noizu.Jira.Error.t()}
  # 〚🔧:𔀪𓱅𓘽𓦦〛 get :: get/4
  def get(client, issue_id_or_key, comment_id, opts \\ []) do
    params = Request.params([expand: :expand], opts)

    Request.request(
      client,
      :get,
      base(issue_id_or_key) <> "/" <> Request.encode_segment(comment_id),
      params: params
    )
  end

  @doc "Updates a comment; plain text is wrapped in ADF. Option: `:notify_users`."
  @spec update(Noizu.Jira.Client.t(), String.t(), String.t(), String.t() | map(), keyword()) ::
          {:ok, map()} | {:error, Noizu.Jira.Error.t()}
  # 〚🔧:𓄆𔈳𓏶𓇁〛 update :: update/5
  def update(client, issue_id_or_key, comment_id, body, opts \\ []) do
    params = Request.params([notify_users: :notifyUsers], opts)

    Request.request(
      client,
      :put,
      base(issue_id_or_key) <> "/" <> Request.encode_segment(comment_id),
      json: %{"body" => ADF.doc(body)},
      params: params
    )
  end

  @doc "Deletes a comment."
  @spec delete(Noizu.Jira.Client.t(), String.t(), String.t()) ::
          {:ok, term()} | {:error, Noizu.Jira.Error.t()}
  # 〚🔧:𓾃𓍞𔑯𔎡〛 delete :: delete/3
  def delete(client, issue_id_or_key, comment_id) do
    Request.request(
      client,
      :delete,
      base(issue_id_or_key) <> "/" <> Request.encode_segment(comment_id)
    )
  end
end
