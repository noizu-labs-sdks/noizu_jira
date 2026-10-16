# 〚🔧:𓙷𔏱𓜼𔄧〛 Noizu.Jira.IssueLinks :: Issue links (platform v3).
defmodule Noizu.Jira.IssueLinks do
  @moduledoc """
  Issue links (platform v3). `link/5` builds the common create payload.

  """

  alias Noizu.Jira.{ADF, Request}

  @doc "Creates a link from a full payload (`type`, `inwardIssue`, `outwardIssue`, optional `comment`)."
  @spec create(Noizu.Jira.Client.t(), map(), keyword()) ::
          {:ok, term()} | {:error, Noizu.Jira.Error.t()}
  # 〚🔧:𓀘𓌘𓨣𓻄〛 create :: create/3
  def create(client, payload, opts \\ []) do
    params = Request.params([notify_users: :notifyUsers], opts)
    Request.request(client, :post, "/rest/api/3/issueLink", json: payload, params: params)
  end

  @doc """
  Links two issues by link-type name:

      Noizu.Jira.IssueLinks.link(client, "Blocks", "PROJ-1", "PROJ-2", comment: "see standup")
  """
  @spec link(Noizu.Jira.Client.t(), String.t(), String.t(), String.t(), keyword()) ::
          {:ok, term()} | {:error, Noizu.Jira.Error.t()}
  # 〚🔧:𐦓𓕮𔌩𓭈〛 link :: link/5
  def link(client, type_name, inward_issue, outward_issue, opts \\ []) do
    payload = %{
      "type" => %{"name" => type_name},
      "inwardIssue" => %{"key" => inward_issue},
      "outwardIssue" => %{"key" => outward_issue}
    }

    payload =
      case opts[:comment] do
        nil -> payload
        text -> Map.put(payload, "comment", %{"body" => ADF.doc(text)})
      end

    create(client, payload, opts)
  end

  @doc """
  Fetches an issue link by id.

  """
  @spec get(Noizu.Jira.Client.t(), String.t()) :: {:ok, map()} | {:error, Noizu.Jira.Error.t()}
  # 〚🔧:𓬏𓘾𓇎𔒅〛 get :: Fetches an issue link by id.
  def get(client, link_id) do
    Request.request(client, :get, "/rest/api/3/issueLink/" <> Request.encode_segment(link_id))
  end

  @doc "Deletes an issue link by id."
  @spec delete(Noizu.Jira.Client.t(), String.t()) ::
          {:ok, term()} | {:error, Noizu.Jira.Error.t()}
  # 〚🔧:𓔥𓓕𓍴𓨇〛 delete :: delete/2
  def delete(client, link_id) do
    Request.request(client, :delete, "/rest/api/3/issueLink/" <> Request.encode_segment(link_id))
  end
end
