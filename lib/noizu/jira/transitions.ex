defmodule Noizu.Jira.Transitions do
  @moduledoc """
  Issue workflow transitions (platform v3).

  〚📦:𓞮𓬥𓊭𔕑〛 Noizu.Jira.Transitions :: Issue workflow transitions (platform v3).
  """

  alias Noizu.Jira.Request

  @doc "Lists the transitions available to the current user on an issue."
  @spec list(Noizu.Jira.Client.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, Noizu.Jira.Error.t()}
  @doc """
  How: takes `client`, `issue_id_or_key`, `opts`

  〚🔧:𓴣𔈩𓽝𓫛〛 list :: list/3
  """
  def list(client, issue_id_or_key, opts \\ []) do
    params = Request.params([expand: :expand], opts)

    Request.request(
      client,
      :get,
      "/rest/api/3/issue/" <> Request.encode_segment(issue_id_or_key) <> "/transitions",
      params: params
    )
  end

  @doc """
  Performs a transition.

      Noizu.Jira.Transitions.perform(client, "PROJ-123", "31",
        fields: %{"resolution" => %{"name" => "Done"}}
      )

  Options: `:fields` (map), `:update` (map).
  """
  @spec perform(Noizu.Jira.Client.t(), String.t(), String.t(), keyword()) ::
          {:ok, term()} | {:error, Noizu.Jira.Error.t()}
  @doc """
  How: takes `client`, `issue_id_or_key`, `transition_id`, `opts`

  〚🔧:𓎡𔀑𓔇𓇼〛 perform :: perform/4
  """
  def perform(client, issue_id_or_key, transition_id, opts \\ []) do
    body =
      %{"transition" => %{"id" => to_string(transition_id)}}
      |> maybe_put("fields", opts[:fields])
      |> maybe_put("update", opts[:update])

    Request.request(
      client,
      :post,
      "/rest/api/3/issue/" <> Request.encode_segment(issue_id_or_key) <> "/transitions",
      json: body
    )
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
