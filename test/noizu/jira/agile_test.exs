defmodule Noizu.Jira.AgileTest do
  use ExUnit.Case, async: true

  import Noizu.Jira.TestSupport

  test "Boards.list uses the agile base path (basic auth)" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    Req.Test.stub(name, fn conn ->
      send(self(), {:path, conn.request_path})
      respond(conn, 200, %{"values" => [%{"id" => 42, "name" => "Main"}], "isLast" => true})
    end)

    assert {:ok, page} = Noizu.Jira.Agile.Boards.list(client, max_results: 10)
    assert page["values"] == [%{"id" => 42, "name" => "Main"}]
    assert_received {:path, "/rest/agile/1.0/board"}
  end

  test "Boards.list prefixes the oauth ex/jira path" do
    name = stub_name()
    cid = cloud_id()
    expected_path = "/ex/jira/" <> cid <> "/rest/agile/1.0/board"
    client = oauth_client(req: [plug: {Req.Test, name}])

    Req.Test.stub(name, fn conn ->
      send(self(), {:path, conn.request_path})
      respond(conn, 200, %{"values" => [], "isLast" => true})
    end)

    assert {:ok, _} = Noizu.Jira.Agile.Boards.list(client)
    assert_received {:path, ^expected_path}
  end

  test "Boards.get/create/delete" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    Req.Test.stub(name, fn conn ->
      case {conn.method, conn.request_path} do
        {"GET", "/rest/agile/1.0/board/42"} ->
          respond(conn, 200, %{"id" => 42})

        {"POST", "/rest/agile/1.0/board"} ->
          {body, conn} = read_json_body(conn)
          send(self(), {:create, body})
          respond(conn, 200, %{"id" => 43})

        {"DELETE", "/rest/agile/1.0/board/42"} ->
          respond(conn, 204, nil)

        _ ->
          respond(conn, 500, %{"errorMessages" => ["unmatched"]})
      end
    end)

    assert {:ok, %{"id" => 42}} = Noizu.Jira.Agile.Boards.get(client, 42)

    assert {:ok, %{"id" => 43}} =
             Noizu.Jira.Agile.Boards.create(client, %{"name" => "Kanban", "type" => "kanban"})

    assert_received {:create, %{"name" => "Kanban"}}
    assert {:ok, nil} = Noizu.Jira.Agile.Boards.delete(client, 42)
  end

  test "Boards.issues uses the enhanced software endpoint with nextPageToken" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    Req.Test.stub(name, fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      send(self(), {:path, conn.request_path, conn.query_params})

      case conn.query_params["nextPageToken"] do
        nil ->
          respond(conn, 200, %{
            "issues" => [%{"key" => "P-1"}],
            "isLast" => false,
            "nextPageToken" => "n1"
          })

        "n1" ->
          respond(conn, 200, %{"issues" => [%{"key" => "P-2"}], "isLast" => true})
      end
    end)

    assert {:ok, page} = Noizu.Jira.Agile.Boards.issues(client, 42, max_results: 1)
    assert page["issues"] == [%{"key" => "P-1"}]

    assert_received {:path, "/rest/software/1.0/board/42/issue", %{"maxResults" => "1"}}

    keys =
      Noizu.Jira.Agile.Boards.issues_stream(client, 42)
      |> Stream.map(& &1["key"])
      |> Enum.to_list()

    assert keys == ["P-1", "P-2"]
  end

  test "Sprints CRUD" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    Req.Test.stub(name, fn conn ->
      case {conn.method, conn.request_path} do
        {"GET", "/rest/agile/1.0/sprint/7"} ->
          respond(conn, 200, %{"id" => 7, "state" => "active"})

        {"POST", "/rest/agile/1.0/sprint"} ->
          respond(conn, 200, %{"id" => 8})

        {"PUT", "/rest/agile/1.0/sprint/7"} ->
          respond(conn, 200, %{"id" => 7})

        {"DELETE", "/rest/agile/1.0/sprint/7"} ->
          respond(conn, 204, nil)

        _ ->
          respond(conn, 500, %{"errorMessages" => ["unmatched"]})
      end
    end)

    mod = Noizu.Jira.Agile.Sprints

    assert {:ok, %{"state" => "active"}} = mod.get(client, 7)

    assert {:ok, %{"id" => 8}} =
             mod.create(client, %{"name" => "Sprint 8", "originBoardId" => 42})

    assert {:ok, %{"id" => 7}} = mod.update(client, 7, %{"state" => "closed"})
    assert {:ok, nil} = mod.delete(client, 7)
  end

  test "Sprints.issues uses the agile offset endpoint and streams" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    Req.Test.stub(name, fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      send(self(), {:path, conn.request_path})

      case conn.query_params["startAt"] do
        "1" -> respond(conn, 200, %{"issues" => [%{"key" => "P-2"}], "isLast" => true})
        nil -> respond(conn, 200, %{"issues" => [%{"key" => "P-1"}], "isLast" => false})
      end
    end)

    assert {:ok, _} = Noizu.Jira.Agile.Sprints.issues(client, 7, max_results: 1)
    assert_received {:path, "/rest/agile/1.0/sprint/7/issue"}

    keys =
      Noizu.Jira.Agile.Sprints.issues_stream(client, 7, max_results: 1)
      |> Stream.map(& &1["key"])
      |> Enum.to_list()

    assert keys == ["P-1", "P-2"]
  end
end
