defmodule Noizu.Jira.RetryTest do
  use ExUnit.Case, async: true

  import Noizu.Jira.TestSupport
  alias Noizu.Jira.Error

  defp counting_client(name, retries) do
    basic_client(req: [plug: {Req.Test, name}], retry: retries)
  end

  test "retries 429 with Retry-After: 0 then succeeds" do
    name = stub_name()
    counter = :counters.new(1, [:atomics])
    parent = self()

    Req.Test.stub(name, fn conn ->
      :counters.add(counter, 1, 1)
      n = :counters.get(counter, 1)

      if n == 1 do
        conn
        |> Plug.Conn.put_resp_header("retry-after", "0")
        |> respond(429, %{"errorMessages" => ["slow down"]})
      else
        respond(conn, 200, %{"key" => "PROJ-1"})
      end
    end)

    client =
      counting_client(name, max_attempts: 3, sleep: fn ms -> send(parent, {:slept, ms}) end)

    assert {:ok, %{"key" => "PROJ-1"}} = Noizu.Jira.Issues.get(client, "PROJ-1")
    assert :counters.get(counter, 1) == 2
    assert_received {:slept, 0}
  end

  test "exhausts attempts on 503 and returns the error" do
    name = stub_name()
    counter = :counters.new(1, [:atomics])

    Req.Test.stub(name, fn conn ->
      :counters.add(counter, 1, 1)
      respond(conn, 503, %{"errorMessages" => ["temporarily unavailable"]})
    end)

    client = counting_client(name, max_attempts: 2, sleep: fn _ms -> :ok end)

    assert {:error, %Error{status: 503}} = Noizu.Jira.Issues.get(client, "PROJ-1")
    assert :counters.get(counter, 1) == 2
  end

  test "Retry-After seconds are honored exactly" do
    name = stub_name()
    counter = :counters.new(1, [:atomics])
    parent = self()

    Req.Test.stub(name, fn conn ->
      :counters.add(counter, 1, 1)
      n = :counters.get(counter, 1)

      if n == 1 do
        conn
        |> Plug.Conn.put_resp_header("retry-after", "2")
        |> respond(429, %{})
      else
        respond(conn, 200, %{})
      end
    end)

    client =
      counting_client(name, max_attempts: 2, sleep: fn ms -> send(parent, {:slept, ms}) end)

    assert {:ok, _} = Noizu.Jira.Issues.get(client, "PROJ-1")
    assert_received {:slept, 2000}
  end

  test "exponential backoff without Retry-After stays within the jitter range" do
    name = stub_name()
    counter = :counters.new(1, [:atomics])
    parent = self()

    Req.Test.stub(name, fn conn ->
      :counters.add(counter, 1, 1)
      respond(conn, 429, %{})
    end)

    client =
      counting_client(name, max_attempts: 2, sleep: fn ms -> send(parent, {:slept, ms}) end)

    assert {:error, %Error{status: 429}} = Noizu.Jira.Issues.get(client, "PROJ-1")
    assert_received {:slept, ms}
    assert ms >= 175 and ms <= 325
  end

  test "400 is not retried" do
    name = stub_name()
    counter = :counters.new(1, [:atomics])

    Req.Test.stub(name, fn conn ->
      :counters.add(counter, 1, 1)
      respond(conn, 400, %{"errors" => %{"summary" => "required"}})
    end)

    client = counting_client(name, max_attempts: 3, sleep: fn _ms -> flunk("must not sleep") end)

    assert {:error, %Error{status: 400, field_errors: %{"summary" => "required"}}} =
             Noizu.Jira.Issues.get(client, "PROJ-1")

    assert :counters.get(counter, 1) == 1
  end

  test "transport failures are not retried and carry status nil" do
    client =
      Noizu.Jira.Client.new(
        auth: {:basic, "user@example.test", "fake-token"},
        base_url: "http://127.0.0.1:1"
      )

    assert {:error, %Error{status: nil, reason: reason}} = Noizu.Jira.Issues.get(client, "PROJ-1")
    assert is_binary(reason) and reason != ""
  end

  test "negative Retry-After clamps to 0 instead of crashing Process.sleep (T-005)" do
    name = stub_name()
    counter = :counters.new(1, [:atomics])

    Req.Test.stub(name, fn conn ->
      :counters.add(counter, 1, 1)
      conn |> Plug.Conn.put_resp_header("retry-after", "-1") |> respond(429, %{})
    end)

    # Default Process.sleep/1 path: a negative value used to raise FunctionClauseError.
    client = counting_client(name, max_attempts: 2)

    assert {:error, %Error{status: 429}} = Noizu.Jira.Issues.get(client, "PROJ-1")
    assert :counters.get(counter, 1) == 2
  end

  test "huge Retry-After clamps to max_sleep_ms (T-005)" do
    name = stub_name()
    parent = self()

    Req.Test.stub(name, fn conn ->
      conn |> Plug.Conn.put_resp_header("retry-after", "999999999") |> respond(429, %{})
    end)

    client =
      counting_client(name, max_attempts: 2, sleep: fn ms -> send(parent, {:slept, ms}) end)

    assert {:error, %Error{status: 429}} = Noizu.Jira.Issues.get(client, "PROJ-1")
    assert_received {:slept, 30_000}
  end

  test "huge Retry-After honors a custom max_sleep_ms cap (T-005)" do
    name = stub_name()
    parent = self()

    Req.Test.stub(name, fn conn ->
      conn |> Plug.Conn.put_resp_header("retry-after", "999999999") |> respond(429, %{})
    end)

    client =
      counting_client(name,
        max_attempts: 2,
        max_sleep_ms: 500,
        sleep: fn ms -> send(parent, {:slept, ms}) end
      )

    assert {:error, %Error{status: 429}} = Noizu.Jira.Issues.get(client, "PROJ-1")
    assert_received {:slept, 500}
  end

  test "garbage Retry-After falls back to exponential backoff (T-005)" do
    name = stub_name()
    parent = self()

    Req.Test.stub(name, fn conn ->
      conn |> Plug.Conn.put_resp_header("retry-after", "soon") |> respond(429, %{})
    end)

    client =
      counting_client(name, max_attempts: 2, sleep: fn ms -> send(parent, {:slept, ms}) end)

    assert {:error, %Error{status: 429}} = Noizu.Jira.Issues.get(client, "PROJ-1")
    assert_received {:slept, ms}
    assert ms >= 175 and ms <= 325
  end
end
