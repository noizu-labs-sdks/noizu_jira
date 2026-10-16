defmodule Noizu.Jira.TestSupport do
  @moduledoc false

  # Req.Test plug stubs only — no live network, no real credentials.

  def stub_name, do: String.to_atom("jira_stub_#{System.unique_integer([:positive])}")

  def basic_client(opts \\ []) do
    {req_opts, opts} = Keyword.pop(opts, :req, [])

    Noizu.Jira.Client.new(
      [auth: {:basic, "user@example.test", "fake-token"}, site: "example.atlassian.net"] ++
        Keyword.put(opts, :req_opts, req_opts)
    )
  end

  def oauth_client(opts \\ []) do
    {req_opts, opts} = Keyword.pop(opts, :req, [])

    Noizu.Jira.Client.new(
      [auth: {:oauth, "fake-access-token"}, cloud_id: "11112222-3333-4444-5555-666677778888"] ++
        Keyword.put(opts, :req_opts, req_opts)
    )
  end

  def cloud_id, do: "11112222-3333-4444-5555-666677778888"

  @doc "Registers a stub answering `method`/`path` with a JSON body; anything else gets a 500 marker."
  def stub(name, method, path, body, status \\ 200) do
    Req.Test.stub(name, fn conn -> dispatch(conn, method, path, body, status) end)
  end

  @doc "Answers `body` when the request matches `method`/`path`, else a 500 marker."
  def dispatch(conn, method, path, body, status \\ 200) do
    expected_method = String.upcase(to_string(method))

    if conn.method == expected_method and conn.request_path == path do
      respond(conn, status, body)
    else
      respond(conn, 500, %{
        "errorMessages" => ["unmatched: " <> conn.method <> " " <> conn.request_path]
      })
    end
  end

  def respond(conn, status, body) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.resp(status, Jason.encode!(body))
  end

  def respond_binary(conn, status, content_type, body) do
    conn
    |> Plug.Conn.put_resp_content_type(content_type)
    |> Plug.Conn.resp(status, body)
  end

  def read_json_body(conn) do
    {:ok, raw, conn} = Plug.Conn.read_body(conn)

    case Jason.decode(raw) do
      {:ok, decoded} -> {decoded, conn}
      :error -> {raw, conn}
    end
  end

  def query_params(conn) do
    conn = Plug.Conn.fetch_query_params(conn)
    conn.query_params
  end

  def header(conn, name) do
    case List.keyfind(conn.req_headers, name, 0) do
      {^name, value} -> value
      nil -> nil
    end
  end
end
