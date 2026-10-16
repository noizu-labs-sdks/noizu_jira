# 〚🔧:𓴶𔙬𓽸𓏝〛 Noizu.Jira.Client :: Immutable client configuration, passed explicitly to every call.
defmodule Noizu.Jira.Client do
  @moduledoc """
  Immutable client configuration, passed explicitly to every call.

      # Basic auth — https://<site>.atlassian.net
      Noizu.Jira.Client.new(auth: {:basic, email, api_token}, site: "example.atlassian.net")

      # OAuth 2.0 3LO — https://api.atlassian.com/ex/jira/<cloudId>
      Noizu.Jira.Client.new(auth: {:oauth, access_token}, cloud_id: cloud_id)

  Options:

    * `:auth` (required) — `{:basic, email, api_token}` or `{:oauth, access_token}`
    * `:site` — a bare subdomain (`"acme"`, completed to `acme.atlassian.net`)
      or a full `<sub>.atlassian.net` host (required for basic unless
      `:base_url` is given). A leading `https://` and a trailing `/` are
      tolerated and stripped; the scheme is always re-applied as `https://`.
      Anything else — userinfo (`@`), ports, paths, query strings, foreign
      hosts — is rejected with an `ArgumentError`, because a hostile value
      would receive the `Authorization` header.
    * `:base_url` — explicit escape hatch overriding the URL `:site` /
      `:cloud_id` would produce (proxies, tests). Must be an absolute URL
      with an `https` scheme; `http` is allowed only for `localhost` /
      `127.0.0.1` endpoints. No userinfo, path, query, or fragment.
    * `:cloud_id` — Atlassian cloud id (required for oauth)
    * `:req_opts` — keyword list forwarded to every `Req.new/1` call
      (for example `plug:` for `Req.Test`, finch pool, receive timeouts)
    * `:retry` — overrides: `:max_attempts` (default 3, total tries),
      `:base_sleep_ms` (250), `:max_sleep_ms` (30_000), `:sleep` (fun of
      milliseconds; default `Process.sleep/1`)

  The client is a plain struct with no global state; reuse it across calls and
  processes. Credentials are redacted from `inspect/1` output (only the basic
  email and a 4-character token prefix are shown), so logging the struct does
  not leak tokens.

  """

  defstruct [:auth, :site, :cloud_id, :base_url, :req_opts, :retry]

  @typedoc "Auth mode: basic (email + API token) or OAuth 2.0 3LO bearer token."
  @type auth ::
          {:basic, email :: String.t(), api_token :: String.t()}
          | {:oauth, access_token :: String.t()}

  @type t :: %__MODULE__{
          auth: auth(),
          site: String.t() | nil,
          cloud_id: String.t() | nil,
          base_url: String.t() | nil,
          req_opts: keyword(),
          retry: keyword()
        }

  @default_retry [max_attempts: 3, base_sleep_ms: 250, max_sleep_ms: 30_000]

  @doc """
  Builds a client. Raises `KeyError` without `:auth` and `ArgumentError` on a mode/option mismatch.

  """
  @spec new(keyword()) :: t()
  # 〚🔧:𓟱𓖇𔇁𓹕〛 new :: Builds a client.
  def new(opts) when is_list(opts) do
    auth = Keyword.fetch!(opts, :auth)
    validate_auth!(auth)

    site = normalize_site(opts[:site])
    base_url = normalize_base_url(opts[:base_url])
    cloud_id = opts[:cloud_id]

    case auth do
      {:basic, _, _} ->
        if is_nil(site) and is_nil(base_url),
          do: raise(ArgumentError, "Noizu.Jira.Client :site is required for basic auth")

      {:oauth, _} ->
        unless cloud_id,
          do: raise(ArgumentError, "Noizu.Jira.Client :cloud_id is required for oauth auth")
    end

    %__MODULE__{
      auth: auth,
      site: site,
      cloud_id: cloud_id,
      base_url: base_url,
      req_opts: Keyword.get(opts, :req_opts, []),
      retry: Keyword.merge(@default_retry, Keyword.get(opts, :retry, []))
    }
  end

  # 〚🔧:𓚞𓮴𓂏𓩞〛 base_url :: base_url/1
  @doc false
  @spec base_url(t()) :: String.t()
  def base_url(%__MODULE__{base_url: url}) when is_binary(url), do: url

  def base_url(%__MODULE__{auth: {:basic, _, _}, site: site}), do: "https://" <> site

  def base_url(%__MODULE__{auth: {:oauth, _}, cloud_id: cloud_id}),
    do: "https://api.atlassian.com/ex/jira/" <> cloud_id

  # 〚🔧:𓍸𔑎𔎽𓴬〛 authorization_header :: authorization_header/1
  @doc false
  @spec authorization_header(t()) :: {String.t(), String.t()}
  def authorization_header(%__MODULE__{auth: {:basic, email, api_token}}) do
    {"authorization", "Basic " <> Base.encode64(email <> ":" <> api_token)}
  end

  def authorization_header(%__MODULE__{auth: {:oauth, access_token}}),
    do: {"authorization", "Bearer " <> access_token}

  defp validate_auth!({:basic, email, api_token})
       when is_binary(email) and is_binary(api_token),
       do: :ok

  defp validate_auth!({:oauth, access_token}) when is_binary(access_token), do: :ok

  # T-002: real credentials ride inside malformed tuples, so the raised
  # message (which typically lands in logs) must never interpolate
  # `inspect/1` of the offending value — describe its shape instead.
  defp validate_auth!(other),
    do:
      raise(
        ArgumentError,
        "Noizu.Jira.Client invalid :auth — expected {:basic, email, api_token} or " <>
          "{:oauth, access_token} with binary values, got #{value_shape(other)}"
      )

  defp value_shape(t) when is_tuple(t), do: "#{tuple_size(t)}-element tuple"
  defp value_shape(l) when is_list(l), do: "a list"
  defp value_shape(b) when is_binary(b), do: "a binary"
  defp value_shape(a) when is_atom(a), do: "the atom #{inspect(a)}"
  defp value_shape(n) when is_integer(n), do: "an integer"
  defp value_shape(f) when is_float(f), do: "a float"
  defp value_shape(m) when is_map(m), do: "a map"
  defp value_shape(_), do: "a term of another type"

  # T-003: `:site` is attached to `https://` and carries the Authorization
  # header, so it must be a bare subdomain or a `<sub>.atlassian.net` host.
  # Userinfo (`@`), ports, paths, queries, and foreign hosts are rejected;
  # the error never echoes the offending value (log-injection surface).
  @site_host_pattern ~r/\A[a-z0-9][a-z0-9-]*\.atlassian\.net\z/
  @site_subdomain_pattern ~r/\A[a-z0-9][a-z0-9-]*\z/
  @site_invalid "Noizu.Jira.Client invalid :site — expected a bare subdomain " <>
                  "(e.g. \"acme\") or a full host (e.g. \"acme.atlassian.net\"); " <>
                  "pass :base_url explicitly for proxies, tests, or other endpoints"

  defp normalize_site(nil), do: nil
  defp normalize_site(site) when not is_binary(site), do: raise(ArgumentError, @site_invalid)

  defp normalize_site(site) when is_binary(site) do
    host =
      site
      |> String.downcase()
      |> String.replace_prefix("https://", "")
      |> String.replace_prefix("http://", "")
      |> String.trim_trailing("/")

    cond do
      Regex.match?(@site_host_pattern, host) -> host
      Regex.match?(@site_subdomain_pattern, host) -> host <> ".atlassian.net"
      true -> raise(ArgumentError, @site_invalid)
    end
  end

  # T-003: the one explicit escape hatch for proxies and tests. `http` is
  # only allowed for loopback endpoints; everything credential-bearing stays
  # on verified TLS off localhost.
  @base_url_invalid "Noizu.Jira.Client invalid :base_url — expected an absolute https " <>
                      "URL (http only for localhost/127.0.0.1 test endpoints) with a host " <>
                      "and no userinfo, path, query, or fragment"

  defp normalize_base_url(nil), do: nil

  defp normalize_base_url(url) when not is_binary(url),
    do: raise(ArgumentError, @base_url_invalid)

  defp normalize_base_url(url) when is_binary(url) do
    uri = URI.parse(url)
    host = uri.host || ""
    localhost? = host in ["localhost", "127.0.0.1"]

    if uri.scheme in ["https", "http"] and (uri.scheme == "https" or localhost?) and
         host != "" and is_nil(uri.userinfo) and uri.path in [nil, "", "/"] and
         is_nil(uri.query) and is_nil(uri.fragment) do
      String.trim_trailing(url, "/")
    else
      raise(ArgumentError, @base_url_invalid)
    end
  end
end

# 〚🔧:𓲢𓎩𔒔𓂻〛 Inspect (Noizu.Jira.Client) :: Redacting Inspect implementation (T-001)
defimpl Inspect, for: Noizu.Jira.Client do
  @moduledoc false

  # T-001: `inspect/1` of the client reaches IEx, crash reports, and host
  # logs, so credentials must never appear. At most the basic-auth email and
  # a 4-character token prefix are shown; api_token / access_token never are.
  def inspect(client, _opts) do
    fields =
      [
        auth: auth(client.auth),
        site: client.site,
        cloud_id: client.cloud_id
      ]
      |> Enum.map_join(", ", fn {key, value} -> "#{key}: #{inspect(value)}" end)

    "#Noizu.Jira.Client<" <> fields <> ">"
  end

  defp auth({:basic, email, token}) when is_binary(email) and is_binary(token),
    do: "{:basic, #{inspect(email)}, #{redact(token)}}"

  defp auth({:oauth, token}) when is_binary(token), do: "{:oauth, #{redact(token)}}"
  defp auth(_malformed), do: "{redacted}"

  defp redact(token) when is_binary(token) and byte_size(token) > 4 do
    prefix = binary_part(token, 0, 4)

    if String.valid?(prefix), do: "\"" <> prefix <> "…\"", else: "\"…\""
  end

  # Shorter-than-prefix values are withheld entirely: never render a secret whole.
  defp redact(_), do: "\"…\""
end
