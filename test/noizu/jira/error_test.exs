defmodule Noizu.Jira.ErrorTest do
  use ExUnit.Case, async: true

  alias Noizu.Jira.Error

  test "decode maps errorMessages and errors" do
    error =
      Error.decode(400, %{
        "errorMessages" => ["one", "two"],
        "errors" => %{"summary" => "Summary is required."},
        "status" => 400
      })

    assert error.status == 400
    assert error.messages == ["one", "two"]
    assert error.field_errors == %{"summary" => "Summary is required."}
    assert error.body["status"] == 400
  end

  test "decode tolerates missing keys and non-map bodies" do
    error = Error.decode(404, %{})
    assert error.messages == []
    assert error.field_errors == %{}

    error = Error.decode(502, "<html>bad gateway</html>")
    assert error.status == 502
    assert error.body == "<html>bad gateway</html>"

    error = Error.decode(500, ["unexpected"])
    assert error.body == ["unexpected"]
  end

  test "from_exception captures transport failures" do
    error = Error.from_exception(%RuntimeError{message: "connection refused"})
    assert error.status == nil
    assert error.reason == "connection refused"
    assert error.messages == ["connection refused"]
  end

  test "message renders status, messages, and field errors" do
    error =
      Error.exception(
        status: 400,
        messages: ["Invalid request"],
        field_errors: %{"summary" => "required"}
      )

    assert Exception.message(error) ==
             "jira request failed (400): Invalid request; summary: required"
  end

  test "message renders bare status and transport reasons" do
    assert Exception.message(Error.exception(status: 404)) == "jira request failed (404)"
    assert Exception.message(Error.exception(reason: "timeout")) == "jira request failed: timeout"
  end

  test "errors are raisable" do
    error = Error.decode(429, %{"errorMessages" => ["slow down"]})

    assert_raise Error, "jira request failed (429): slow down", fn -> raise error end
  end
end
