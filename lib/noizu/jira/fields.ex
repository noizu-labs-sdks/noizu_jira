# 〚🔧:𓺞𓃩𔐎𔅵〛 Noizu.Jira.Fields :: Field metadata (platform v3).
defmodule Noizu.Jira.Fields do
  @moduledoc """
  Field metadata (platform v3).

  `list/1` returns the raw decoded body: Atlassian is mid-migration between a
  flat array of fields and a paginated map, so no stream is offered — inspect
  the shape you receive.

  """

  alias Noizu.Jira.Request

  @doc """
  Lists fields (raw body).

  """
  @spec list(Noizu.Jira.Client.t()) :: {:ok, term()} | {:error, Noizu.Jira.Error.t()}
  # 〚🔧:𓚡𓨐𓁺𔔄〛 list :: Lists fields (raw body).
  def list(client), do: Request.request(client, :get, "/rest/api/3/field")
end
