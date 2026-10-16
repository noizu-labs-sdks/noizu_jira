defmodule Noizu.Jira.Worklogs do
  @moduledoc """
  Issue worklogs (platform v3, offset pagination). Comment bodies are ADF;
  plain text is wrapped automatically.

  〚📦:𓈣𓔘𓬓𓷀〛 Noizu.Jira.Worklogs :: Issue worklogs (platform v3, offset pagination).
  """

  alias Noizu.Jira.{ADF, Pagination, Request}

  defp base(issue_id_or_key),
    do: "/rest/api/3/issue/" <> Request.encode_segment(issue_id_or_key) <> "/worklog"

  @estimate_params [
    adjust_estimate: :adjustEstimate,
    new_estimate: :newEstimate,
    reduce_by: :reduceBy,
    notify_users: :notifyUsers,
    override_editable_flag: :overrideEditableFlag
  ]

  @doc "Lists worklogs (offset page: `{worklogs, startAt, maxResults, total}`)."
  @spec list(Noizu.Jira.Client.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, Noizu.Jira.Error.t()}
  @doc """
  How: takes `client`, `issue_id_or_key`, `opts`

  〚🔧:𓥹𔅶𓶖𓚢〛 list :: list/3
  """
  def list(client, issue_id_or_key, opts \\ []) do
    params =
      Request.params([start_at: :startAt, max_results: :maxResults, expand: :expand], opts)

    Request.request(client, :get, base(issue_id_or_key), params: params)
  end

  @doc """
  Lazily streams every worklog. Raises `Noizu.Jira.Error` on page failure.

  〚🔧:𓊲𓲑𓷑𔄦〛 stream :: Lazily streams every worklog.
  """
  @spec stream(Noizu.Jira.Client.t(), String.t(), keyword()) :: Enumerable.t()
  def stream(client, issue_id_or_key, opts \\ []) do
    refetch = fn start -> list(client, issue_id_or_key, Keyword.put(opts, :start_at, start)) end

    Pagination.stream(
      fn :first -> list(client, issue_id_or_key, opts) end,
      &Map.get(&1, "worklogs", []),
      fn page ->
        Pagination.offset_next(page, refetch, &Map.get(&1, "worklogs", []))
      end
    )
  end

  @doc """
  Adds a worklog.

      Noizu.Jira.Worklogs.add(client, "PROJ-123",
        time_spent: "1h 30m",
        comment: "pairing",
        adjust_estimate: "auto"
      )

  Options — body: `:time_spent`, `:time_spent_seconds`, `:started`, `:comment`
  (ADF), `:visibility`, `:properties`; query: `:adjust_estimate`, `:new_estimate`,
  `:reduce_by`, `:notify_users`, `:override_editable_flag`.
  """
  @spec add(Noizu.Jira.Client.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, Noizu.Jira.Error.t()}
  @doc """
  How: takes `client`, `issue_id_or_key`, `opts`

  〚🔧:𓜖𔅗𓻄𓓅〛 add :: add/3
  """
  def add(client, issue_id_or_key, opts \\ []) do
    body =
      %{}
      |> maybe_put("timeSpent", opts[:time_spent])
      |> maybe_put("timeSpentSeconds", opts[:time_spent_seconds])
      |> maybe_put("started", opts[:started])
      |> maybe_put("comment", adf(opts[:comment]))
      |> maybe_put("visibility", opts[:visibility])
      |> maybe_put("properties", opts[:properties])

    Request.request(client, :post, base(issue_id_or_key),
      json: body,
      params: Request.params(@estimate_params, opts)
    )
  end

  @doc "Updates a worklog; same options as `add/3`."
  @spec update(Noizu.Jira.Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, Noizu.Jira.Error.t()}
  @doc """
  How: takes `client`, `issue_id_or_key`, `worklog_id`, `opts`

  〚🔧:𓳶𔒚𔖉𔀓〛 update :: update/4
  """
  def update(client, issue_id_or_key, worklog_id, opts \\ []) do
    body =
      %{}
      |> maybe_put("timeSpent", opts[:time_spent])
      |> maybe_put("timeSpentSeconds", opts[:time_spent_seconds])
      |> maybe_put("comment", adf(opts[:comment]))

    Request.request(
      client,
      :put,
      base(issue_id_or_key) <> "/" <> Request.encode_segment(worklog_id),
      json: body,
      params: Request.params(@estimate_params, opts)
    )
  end

  @doc "Deletes a worklog; estimate options as in `add/3`."
  @spec delete(Noizu.Jira.Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, term()} | {:error, Noizu.Jira.Error.t()}
  @doc """
  How: takes `client`, `issue_id_or_key`, `worklog_id`, `opts`

  〚🔧:𔙡𓨮𔄫𔘎〛 delete :: delete/4
  """
  def delete(client, issue_id_or_key, worklog_id, opts \\ []) do
    Request.request(
      client,
      :delete,
      base(issue_id_or_key) <> "/" <> Request.encode_segment(worklog_id),
      params: Request.params(@estimate_params, opts)
    )
  end

  defp adf(nil), do: nil
  defp adf(body), do: ADF.doc(body)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
