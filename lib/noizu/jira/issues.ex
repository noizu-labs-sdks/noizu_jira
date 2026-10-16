# 〚🔧:𓏯𔐐𓲭𔃞〛 Noizu.Jira.Issues :: Issue CRUD against the platform v3 API.
defmodule Noizu.Jira.Issues do
  @moduledoc """
  Issue CRUD against the platform v3 API.

  All `fields`/`update` maps are passed through as-is; descriptions and other ADF
  fields must be Atlassian Document Format (use [`Noizu.Jira.ADF.doc/1`](`Noizu.Jira.ADF`)
  for plain text).

  """

  alias Noizu.Jira.Request

  @doc """
  Creates an issue.

      Noizu.Jira.Issues.create(client, %{
        "project" => %{"key" => "PROJ"},
        "issuetype" => %{"name" => "Task"},
        "summary" => "Ship it",
        "description" => Noizu.Jira.ADF.doc("hello")
      })

  Options: `:update` (map), `:properties` (list), `:transition` (map), `:update_history` (boolean).
  """
  @spec create(Noizu.Jira.Client.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Noizu.Jira.Error.t()}
  # 〚🔧:𓨅𓨾𓌳𓚠〛 create :: create/3
  def create(client, fields, opts \\ []) do
    body =
      %{"fields" => fields}
      |> maybe_put("update", opts[:update])
      |> maybe_put("properties", opts[:properties])
      |> maybe_put("transition", opts[:transition])

    params = Request.params([update_history: :updateHistory], opts)
    Request.request(client, :post, "/rest/api/3/issue", json: body, params: params)
  end

  @doc "Fetches an issue by id or key. Options: `:fields`, `:expand`, `:properties`, `:fail_fast`."
  @spec get(Noizu.Jira.Client.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, Noizu.Jira.Error.t()}
  # 〚🔧:𓊑𓬖𔕭𓝣〛 get :: get/3
  def get(client, issue_id_or_key, opts \\ []) do
    params =
      Request.params(
        [fields: :fields, expand: :expand, properties: :properties, fail_fast: :failFast],
        opts
      )

    Request.request(client, :get, "/rest/api/3/issue/" <> Request.encode_segment(issue_id_or_key),
      params: params
    )
  end

  @doc "Edits an issue. Options: `:update` (map), `:notify_users`, `:override_screen_security`, `:override_editable_flag`."
  @spec edit(Noizu.Jira.Client.t(), String.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Noizu.Jira.Error.t()}
  # 〚🔧:𔑵𓗏𔂺𐦏〛 edit :: edit/4
  def edit(client, issue_id_or_key, fields, opts \\ []) do
    body =
      %{"fields" => fields}
      |> maybe_put("update", opts[:update])

    params =
      Request.params(
        [
          notify_users: :notifyUsers,
          override_screen_security: :overrideScreenSecurity,
          override_editable_flag: :overrideEditableFlag
        ],
        opts
      )

    Request.request(client, :put, "/rest/api/3/issue/" <> Request.encode_segment(issue_id_or_key),
      json: body,
      params: params
    )
  end

  @doc "Deletes an issue. Option: `:delete_subtasks` (boolean, default false server-side)."
  @spec delete(Noizu.Jira.Client.t(), String.t(), keyword()) ::
          {:ok, term()} | {:error, Noizu.Jira.Error.t()}
  # 〚🔧:𔈇𔖻𓠖𔔩〛 delete :: delete/3
  def delete(client, issue_id_or_key, opts \\ []) do
    params = Request.params([delete_subtasks: :deleteSubtasks], opts)

    Request.request(
      client,
      :delete,
      "/rest/api/3/issue/" <> Request.encode_segment(issue_id_or_key),
      params: params
    )
  end

  @doc """
  Creates up to 50 issues in one call. `issue_updates` is a list of
  `%{"fields" => ..., "update"? => ...}` maps; returns the per-issue result list
  (`{"issues": [...], "errors": [...], ...}`).
  """
  @spec bulk_create(Noizu.Jira.Client.t(), [map()], keyword()) ::
          {:ok, map()} | {:error, Noizu.Jira.Error.t()}
  # 〚🔧:𓊢𔃻𔈚𔙗〛 bulk_create :: bulk_create/3
  def bulk_create(client, issue_updates, opts \\ []) do
    params = Request.params([update_history: :updateHistory], opts)

    Request.request(client, :post, "/rest/api/3/issue/bulk",
      json: %{"issueUpdates" => issue_updates},
      params: params
    )
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
