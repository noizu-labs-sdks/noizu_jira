defmodule Noizu.Jira.IssueLinksTest do
  use ExUnit.Case, async: true

  import Noizu.Jira.TestSupport
  alias Noizu.Jira.IssueLinks

  test "create posts the payload as-is" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    payload = %{
      "type" => %{"name" => "Blocks"},
      "inwardIssue" => %{"key" => "PROJ-1"},
      "outwardIssue" => %{"key" => "PROJ-2"}
    }

    Req.Test.stub(name, fn conn ->
      {body, conn} = read_json_body(conn)
      send(self(), {:body, body})
      respond(conn, 201, nil)
    end)

    assert {:ok, nil} = IssueLinks.create(client, payload)
    assert_received {:body, ^payload}
  end

  test "link builds the payload with an optional ADF comment" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    Req.Test.stub(name, fn conn ->
      {body, conn} = read_json_body(conn)
      send(self(), {:body, body})
      respond(conn, 201, nil)
    end)

    assert {:ok, nil} =
             IssueLinks.link(client, "Blocks", "PROJ-1", "PROJ-2", comment: "see standup")

    assert_received {:body, body}
    assert body["type"] == %{"name" => "Blocks"}
    assert body["inwardIssue"] == %{"key" => "PROJ-1"}
    assert body["outwardIssue"] == %{"key" => "PROJ-2"}
    assert body["comment"]["body"]["type"] == "doc"
  end

  test "get and delete use the link path" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    Req.Test.stub(name, fn conn ->
      case {conn.method, conn.request_path} do
        {"GET", "/rest/api/3/issueLink/10"} -> respond(conn, 200, %{"id" => "10"})
        {"DELETE", "/rest/api/3/issueLink/10"} -> respond(conn, 204, nil)
        _ -> respond(conn, 500, %{"errorMessages" => ["unmatched"]})
      end
    end)

    assert {:ok, %{"id" => "10"}} = IssueLinks.get(client, "10")
    assert {:ok, nil} = IssueLinks.delete(client, "10")
  end
end
