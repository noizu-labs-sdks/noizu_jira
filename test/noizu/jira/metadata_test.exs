defmodule Noizu.Jira.MetadataTest do
  use ExUnit.Case, async: true

  import Noizu.Jira.TestSupport

  test "Fields.list returns the raw body" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    stub(name, :get, "/rest/api/3/field", [%{"id" => "summary", "name" => "Summary"}])
    assert {:ok, [%{"id" => "summary"}]} = Noizu.Jira.Fields.list(client)
  end

  test "IssueTypes.list returns the raw array" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    stub(name, :get, "/rest/api/3/issuetype", [%{"id" => "1", "name" => "Task"}])
    assert {:ok, [%{"name" => "Task"}]} = Noizu.Jira.IssueTypes.list(client)
  end

  test "IssueTypes.get fetches by id" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    stub(name, :get, "/rest/api/3/issuetype/1", %{"id" => "1", "name" => "Task"})
    assert {:ok, %{"name" => "Task"}} = Noizu.Jira.IssueTypes.get(client, "1")
  end

  test "Statuses.list uses the legacy flat endpoint" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    stub(name, :get, "/rest/api/3/status", [%{"id" => "1", "name" => "To Do"}])
    assert {:ok, [%{"name" => "To Do"}]} = Noizu.Jira.Statuses.list(client)
  end

  test "Statuses.search and stream use the paginated endpoint" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    Req.Test.stub(name, fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)

      case conn.query_params["startAt"] do
        "1" -> respond(conn, 200, %{"values" => [%{"name" => "Done"}], "isLast" => true})
        nil -> respond(conn, 200, %{"values" => [%{"name" => "To Do"}], "isLast" => false})
      end
    end)

    assert {:ok, page} = Noizu.Jira.Statuses.search(client, project_id: 1)
    assert page["values"] == [%{"name" => "To Do"}]

    names =
      Noizu.Jira.Statuses.stream(client, max_results: 1)
      |> Stream.map(& &1["name"])
      |> Enum.to_list()

    assert names == ["To Do", "Done"]
  end
end
