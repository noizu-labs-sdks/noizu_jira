defmodule Noizu.Jira.IssuesTest do
  use ExUnit.Case, async: true

  import Noizu.Jira.TestSupport
  alias Noizu.Jira.Issues

  test "create posts the fields payload" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    fields = %{"project" => %{"key" => "PROJ"}, "summary" => "Ship it"}

    Req.Test.stub(name, fn conn ->
      {body, conn} = read_json_body(conn)
      send(self(), {:body, body, query_params(conn)})
      respond(conn, 201, %{"key" => "PROJ-1"})
    end)

    assert {:ok, %{"key" => "PROJ-1"}} = Issues.create(client, fields, update_history: true)

    assert_received {:body, body, params}
    assert body == %{"fields" => fields}
    assert params["updateHistory"] == "true"
  end

  test "create includes update/properties/transition extras" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    Req.Test.stub(name, fn conn ->
      {body, conn} = read_json_body(conn)
      send(self(), {:body, body})
      respond(conn, 201, %{"key" => "PROJ-2"})
    end)

    Issues.create(client, %{"summary" => "x"},
      update: %{"labels" => [%{"add" => "a"}]},
      properties: [%{"key" => "k"}],
      transition: %{"id" => "5"}
    )

    assert_received {:body, body}
    assert body["update"] == %{"labels" => [%{"add" => "a"}]}
    assert body["properties"] == [%{"key" => "k"}]
    assert body["transition"] == %{"id" => "5"}
  end

  test "get sends field params" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    Req.Test.stub(name, fn conn ->
      send(self(), {:params, query_params(conn)})
      dispatch(conn, :get, "/rest/api/3/issue/PROJ-1", %{"key" => "PROJ-1"})
    end)

    assert {:ok, _} =
             Issues.get(client, "PROJ-1", fields: ["summary", "status"], expand: ["changelog"])

    assert_received {:params, params}
    assert params["fields"] == "summary,status"
    assert params["expand"] == "changelog"
  end

  test "edit PUTs fields" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    Req.Test.stub(name, fn conn ->
      {body, conn} = read_json_body(conn)
      send(self(), {:body, body})
      respond(conn, 204, nil)
    end)

    assert {:ok, nil} = Issues.edit(client, "PROJ-1", %{"summary" => "new"})
    assert_received {:body, %{"fields" => %{"summary" => "new"}}}
  end

  test "delete sends deleteSubtasks" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    Req.Test.stub(name, fn conn ->
      send(self(), {:params, query_params(conn)})
      respond(conn, 204, nil)
    end)

    assert {:ok, nil} = Issues.delete(client, "PROJ-1", delete_subtasks: true)
    assert_received {:params, %{"deleteSubtasks" => "true"}}
  end

  test "bulk_create wraps issueUpdates" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    update = %{"fields" => %{"project" => %{"key" => "PROJ"}, "summary" => "a"}}

    Req.Test.stub(name, fn conn ->
      {body, conn} = read_json_body(conn)
      send(self(), {:body, body})
      respond(conn, 201, %{"issues" => [%{"key" => "PROJ-1"}]})
    end)

    assert {:ok, %{"issues" => [%{"key" => "PROJ-1"}]}} = Issues.bulk_create(client, [update])

    assert_received {:body, %{"issueUpdates" => [^update]}}
  end
end
