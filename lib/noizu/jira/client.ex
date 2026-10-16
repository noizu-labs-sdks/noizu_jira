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
    * `:site` — `<site>.atlassian.net` (required for basic); `https://` and a
      trailing `/` are stripped, the scheme is always re-applied as `https://`
    * `:cloud_id` — Atlassian cloud id (required for oauth)
    * `:req_opts` — keyword list forwarded to every `Req.new/1` call
      (for example `plug:` for `Req.Test`, finch pool, receive timeouts)
    * `:retry` — overrides: `:max_attempts` (default 3, total tries),
      `:base_sleep_ms` (250), `:max_sleep_ms` (30_000), `:sleep` (fun of
      milliseconds; default `Process.sleep/1`)

  The client is a plain struct with no global state; reuse it across calls and
  processes.

  """

  defstruct [:auth, :site, :cloud_id, :req_opts, :retry]

  @typedoc "Auth mode: basic (email + API token) or OAuth 2.0 3LO bearer token."
  @type auth ::
          {:basic, email :: String.t(), api_token :: String.t()}
          | {:oauth, access_token :: String.t()}

  @type t :: %__MODULE__{
          auth: auth(),
          site: String.t() | nil,
          cloud_id: String.t() | nil,
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
    cloud_id = opts[:cloud_id]

    case auth do
      {:basic, _, _} ->
        unless site,
          do: raise(ArgumentError, "Noizu.Jira.Client :site is required for basic auth")

      {:oauth, _} ->
        unless cloud_id,
          do: raise(ArgumentError, "Noizu.Jira.Client :cloud_id is required for oauth auth")
    end

    %__MODULE__{
      auth: auth,
      site: site,
      cloud_id: cloud_id,
      req_opts: Keyword.get(opts, :req_opts, []),
      retry: Keyword.merge(@default_retry, Keyword.get(opts, :retry, []))
    }
  end

  # 〚🔧:𓚞𓮴𓂏𓩞〛 base_url :: base_url/1
  @doc false
  @spec base_url(t()) :: String.t()
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

  defp validate_auth!(other),
    do: raise(ArgumentError, "Noizu.Jira.Client invalid :auth #{inspect(other)}")

  defp normalize_site(nil), do: nil

  defp normalize_site(site) when is_binary(site) do
    site
    |> String.replace_prefix("https://", "")
    |> String.replace_prefix("http://", "")
    |> String.trim_trailing("/")
  end
end
