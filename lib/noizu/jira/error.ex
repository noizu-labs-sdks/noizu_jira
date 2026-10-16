# 〚🔧:𓊃𔓚𓩏𓽛〛 Noizu.Jira.Error :: Error returned by every fallible client call.
defmodule Noizu.Jira.Error do
  @moduledoc """
  Error returned by every fallible client call.

  Mirrors the Jira Cloud "error collection" payload
  (`{"errorMessages": [...], "errors": {"field": "message"}}`):

      {:error, %Noizu.Jira.Error{
        status: 400,
        messages: ["..."],
        field_errors: %{"summary" => "Summary is required."},
        reason: nil,
        body: %{"errorMessages" => [...]}
      }}

  HTTP failures populate `status` (plus `messages`/`field_errors` when the body
  decodes as an error collection). Transport failures (DNS, connect, timeouts)
  populate `reason` with `status: nil` and are never retried by the client.
  Streams raise this struct on mid-stream page failures.

  """

  defexception status: nil, messages: [], field_errors: %{}, reason: nil, body: nil

  @type t :: %__MODULE__{
          status: pos_integer() | nil,
          messages: [String.t()],
          field_errors: %{optional(String.t()) => term()},
          reason: String.t() | nil,
          body: term()
        }

  # 〚🔧:𔈚𔘻𓥿𓳻〛 exception :: exception/1
  @doc false
  @spec exception(keyword()) :: t()
  def exception(opts) when is_list(opts) do
    %__MODULE__{
      status: opts[:status],
      messages: opts[:messages] || [],
      field_errors: opts[:field_errors] || %{},
      reason: opts[:reason],
      body: opts[:body]
    }
  end

  # 〚🔧:𓥆𓖻𓶇𔖡〛 decode :: decode/2
  @doc false
  @spec decode(pos_integer(), term()) :: t()
  def decode(status, body) when is_map(body) do
    exception(
      status: status,
      messages: List.wrap(body["errorMessages"]),
      field_errors: body["errors"] || %{},
      body: body
    )
  end

  def decode(status, body), do: exception(status: status, body: body)

  # 〚🔧:𓕃𓯌𓵠𔔂〛 from_exception :: from_exception/1
  @doc false
  @spec from_exception(Exception.t()) :: t()
  def from_exception(exception) do
    reason = Exception.message(exception)
    exception(reason: reason, messages: [reason])
  end

  @impl true
  # 〚🔧:𓥹𓱘𓵘𓃪〛 message :: message/1
  def message(%__MODULE__{status: nil, reason: reason}) when is_binary(reason) and reason != "",
    do: "jira request failed: " <> reason

  def message(%__MODULE__{status: nil}), do: "jira request failed"

  def message(%__MODULE__{status: status} = error) do
    parts =
      (error.messages ++ Enum.map(error.field_errors, fn {field, text} -> "#{field}: #{text}" end))
      |> Enum.join("; ")

    base = "jira request failed (#{status})"

    if parts == "", do: base, else: base <> ": " <> parts
  end
end
