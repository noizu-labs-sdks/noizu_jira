defmodule Noizu.Jira.IssueTypes do
  @moduledoc """
  Issue types (platform v3). `list/1` returns the raw array body.

  〚📦:𔇘𓚻𓆷𔌣〛 Noizu.Jira.IssueTypes :: Issue types (platform v3).
  """

  alias Noizu.Jira.Request

  @doc """
  Lists issue types for the license.

  〚🔧:𓁅𓆓𓒜𓖹〛 list :: Lists issue types for the license.
  """
  @spec list(Noizu.Jira.Client.t()) :: {:ok, [map()]} | {:error, Noizu.Jira.Error.t()}
  def list(client), do: Request.request(client, :get, "/rest/api/3/issuetype")

  @doc "Fetches an issue type by id. Option: `:expand`."
  @spec get(Noizu.Jira.Client.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, Noizu.Jira.Error.t()}
  @doc """
  How: takes `client`, `issue_type_id`, `opts`

  〚🔧:𔖰𔀯𓆻𓝖〛 get :: get/3
  """
  def get(client, issue_type_id, opts \\ []) do
    params = Request.params([expand: :expand], opts)

    Request.request(
      client,
      :get,
      "/rest/api/3/issuetype/" <> Request.encode_segment(issue_type_id),
      params: params
    )
  end
end
