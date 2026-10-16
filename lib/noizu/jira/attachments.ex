defmodule Noizu.Jira.Attachments do
  @moduledoc """
  Issue attachments (platform v3). Uploads are multipart/form-data streamed from
  disk and carry the mandatory `X-Atlassian-Token: no-check` CSRF-exemption
  header. Content downloads return raw binaries.

  〚📦:𓢒𓥿𔑌𓳷〛 Noizu.Jira.Attachments :: Issue attachments (platform v3).
  """

  alias Noizu.Jira.Request

  @no_check [{"x-atlassian-token", "no-check"}]

  @doc """
  Uploads a file as an attachment.

      Noizu.Jira.Attachments.add(client, "PROJ-123", "/tmp/trace.log")
      Noizu.Jira.Attachments.add(client, "PROJ-123", "/tmp/a.log", filename: "trace.log")

  The default part filename is the path's basename; `:filename` overrides it.
  """
  @spec add(Noizu.Jira.Client.t(), String.t(), Path.t(), keyword()) ::
          {:ok, map()} | {:error, Noizu.Jira.Error.t()}
  @doc """
  How: takes `client`, `issue_id_or_key`, `path`, `opts`

  〚🔧:𓨉𓅸𓐉𔖲〛 add :: add/4
  """
  def add(client, issue_id_or_key, path, opts \\ []) do
    stream = File.stream!(path, 65_536)
    entry = if filename = opts[:filename], do: {stream, filename: filename}, else: stream

    Request.request(
      client,
      :post,
      "/rest/api/3/issue/" <> Request.encode_segment(issue_id_or_key) <> "/attachments",
      form_multipart: [file: entry],
      headers: @no_check
    )
  end

  @doc """
  Fetches attachment metadata.

  〚🔧:𔈗𓲫𔘝𓻒〛 get :: Fetches attachment metadata.
  """
  @spec get(Noizu.Jira.Client.t(), String.t()) :: {:ok, map()} | {:error, Noizu.Jira.Error.t()}
  def get(client, attachment_id) do
    Request.request(
      client,
      :get,
      "/rest/api/3/attachment/" <> Request.encode_segment(attachment_id)
    )
  end

  @doc "Downloads attachment content as a binary."
  @spec content(Noizu.Jira.Client.t(), String.t()) ::
          {:ok, binary()} | {:error, Noizu.Jira.Error.t()}
  @doc """
  How: takes `client`, `attachment_id`

  〚🔧:𔀠𓼽𔉳𓭉〛 content :: content/2
  """
  def content(client, attachment_id) do
    Request.request(
      client,
      :get,
      "/rest/api/3/attachment/content/" <> Request.encode_segment(attachment_id),
      raw: true
    )
  end

  @doc "Deletes an attachment."
  @spec delete(Noizu.Jira.Client.t(), String.t()) ::
          {:ok, term()} | {:error, Noizu.Jira.Error.t()}
  @doc """
  How: takes `client`, `attachment_id`

  〚🔧:𓇔𓢬𓌂𓨃〛 delete :: delete/2
  """
  def delete(client, attachment_id) do
    Request.request(
      client,
      :delete,
      "/rest/api/3/attachment/" <> Request.encode_segment(attachment_id)
    )
  end
end
