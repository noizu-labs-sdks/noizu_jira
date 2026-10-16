defmodule Noizu.Jira.Request do
  # 〚📦:𓡐𓻠𓅱𔑎〛 Noizu.Jira.Request :: Noizu.Jira.Request module
  @moduledoc false

  # Internal single-request executor: URL assembly, auth header, JSON decoding,
  # the 429/503 retry loop honoring Retry-After, and error decoding. The HTTP
  # client's own retry machinery is disabled so exactly one policy owns retries.

  alias Noizu.Jira.{Client, Error}

  @retry_statuses [429, 503]

  @type method :: :get | :post | :put | :delete
  @type opts :: [
          params: [{String.t(), String.t()}],
          json: map(),
          form_multipart: list(),
          headers: [{String.t(), String.t()}],
          raw: boolean()
        ]

  @spec request(Client.t(), method(), String.t(), opts()) ::
          {:ok, term()} | {:error, Error.t()}
  @doc """
  How: takes `client`, `method`, `path`, `opts`

  〚🔧:𓜃𓣇𔌻𓓜〛 request :: request/4
  """
  def request(client, method, path, opts \\ []) do
    query = params_query(opts[:params])

    req =
      [
        retry: false,
        method: method,
        url: Client.base_url(client) <> path <> query,
        headers: headers(client, opts[:headers])
      ]
      |> Keyword.merge(body_opts(opts))
      |> Keyword.merge(client.req_opts)
      |> Req.new()

    run(req, client, 1)
  end

  # 〚🔧:𓩅𓧎𓡀𓊞〛 encode_segment :: encode_segment/1
  @doc false
  @spec encode_segment(term()) :: String.t()
  def encode_segment(segment), do: URI.encode(to_string(segment), &URI.char_unreserved?/1)

  # Query building. Queries are encoded here, never handed to Req's `:params`,
  # because Req encodes list values as `key[]=` which the Jira API rejects.
  # Each parameter follows its OpenAPI style/explode as documented per endpoint:
  #
  #   * `:csv` (default) — form/explode=false: a single comma-joined value
  #     (`fields=summary,status`, `expand=changelog`, `properties=*all`).
  #   * `:multi` — form/explode=true: the key repeats per value
  #     (`keys=PA&keys=PB` on `GET /rest/api/3/project/search`, `status=...`).
  #
  # Values may be given as lists or scalars; both shapes are normalised.

  @doc false
  @spec params([{atom(), atom()} | {atom(), atom(), :csv | :multi}], keyword()) :: [
          {String.t(), String.t()}
        ]
  @doc """
  How: takes `pairs`, `opts`; guards `is_list(pairs)`

  〚🔧:𔀌𓣲𓦅𔓸〛 params :: params/2
  """
  def params(pairs, opts) when is_list(pairs) do
    Enum.flat_map(pairs, fn
      {opt_key, param_name} -> encode_param(param_name, Keyword.get(opts, opt_key), :csv)
      {opt_key, param_name, style} -> encode_param(param_name, Keyword.get(opts, opt_key), style)
    end)
  end

  defp encode_param(_name, nil, _style), do: []

  defp encode_param(name, values, :csv) when is_list(values) do
    [{to_string(name), Enum.map_join(values, ",", &to_string/1)}]
  end

  defp encode_param(name, value, :csv), do: [{to_string(name), to_string(value)}]

  defp encode_param(name, values, :multi) when is_list(values) do
    Enum.map(values, &{to_string(name), to_string(&1)})
  end

  defp encode_param(name, value, :multi), do: [{to_string(name), to_string(value)}]

  # 〚🔧:𔇂𓉨𓧓𔁾〛 params_query :: params_query/1
  @doc false
  @spec params_query([{String.t(), String.t()}] | nil) :: String.t()
  def params_query(nil), do: ""
  def params_query([]), do: ""
  def params_query(pairs), do: "?" <> URI.encode_query(pairs)

  defp headers(client, extra) do
    [Client.authorization_header(client)] ++ List.wrap(extra)
  end

  defp body_opts(opts) do
    []
    |> put_opt(:json, opts[:json])
    |> put_opt(:form_multipart, opts[:form_multipart])
    |> put_opt(:decode_body, if(opts[:raw], do: false))
  end

  defp put_opt(list, _key, nil), do: list
  defp put_opt(list, key, value), do: Keyword.put(list, key, value)

  defp run(req, client, attempt) do
    case Req.request(req) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body, headers: headers}}
      when status in @retry_statuses ->
        retry(req, client, attempt, status, body, headers)

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, Error.decode(status, body)}

      {:error, exception} ->
        {:error, Error.from_exception(exception)}
    end
  end

  defp retry(req, client, attempt, status, body, headers) do
    retry = client.retry
    max_attempts = Keyword.get(retry, :max_attempts, 3)

    if attempt < max_attempts do
      headers
      |> retry_after_ms()
      |> sleep_ms(retry, attempt)
      |> sleep(retry)

      run(req, client, attempt + 1)
    else
      {:error, Error.decode(status, body)}
    end
  end

  defp sleep_ms(retry_after, _retry, _attempt) when is_integer(retry_after), do: retry_after

  defp sleep_ms(nil, retry, attempt) do
    base = Keyword.get(retry, :base_sleep_ms, 250)
    cap = Keyword.get(retry, :max_sleep_ms, 30_000)

    min(base * 2 ** (attempt - 1), cap) |> jitter()
  end

  defp jitter(ms), do: trunc(ms * (0.7 + :rand.uniform() * 0.6))

  defp retry_after_ms(headers) do
    case headers["retry-after"] do
      [value | _] ->
        case Integer.parse(value) do
          {seconds, _rest} -> seconds * 1000
          :error -> nil
        end

      _ ->
        nil
    end
  end

  defp sleep(ms, retry) do
    case Keyword.get(retry, :sleep) do
      fun when is_function(fun, 1) -> fun.(ms)
      _ -> Process.sleep(ms)
    end
  end
end
