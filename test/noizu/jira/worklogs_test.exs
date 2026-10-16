defmodule Noizu.Jira.WorklogsTest do
  use ExUnit.Case, async: true

  import Noizu.Jira.TestSupport
  alias Noizu.Jira.Worklogs

  test "add posts time spent and ADF comment with estimate params" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    Req.Test.stub(name, fn conn ->
      {body, conn} = read_json_body(conn)
      send(self(), {:body, body, query_params(conn)})
      respond(conn, 201, %{"id" => "10"})
    end)

    assert {:ok, %{"id" => "10"}} =
             Worklogs.add(client, "PROJ-1",
               time_spent: "1h 30m",
               comment: "pairing",
               adjust_estimate: "new",
               new_estimate: "2h"
             )

    assert_received {:body, body, params}
    assert body["timeSpent"] == "1h 30m"
    assert body["comment"]["type"] == "doc"
    assert params["adjustEstimate"] == "new"
    assert params["newEstimate"] == "2h"
  end

  test "add supports timeSpentSeconds without a comment" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    Req.Test.stub(name, fn conn ->
      {body, conn} = read_json_body(conn)
      send(self(), {:body, body})
      respond(conn, 201, %{"id" => "11"})
    end)

    assert {:ok, _} = Worklogs.add(client, "PROJ-1", time_spent_seconds: 900)
    assert_received {:body, body}
    assert body == %{"timeSpentSeconds" => 900}
  end

  test "update PUTs the worklog path" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    Req.Test.stub(name, fn conn ->
      {body, conn} = read_json_body(conn)
      send(self(), {:body, body, conn.request_path})
      respond(conn, 200, %{"id" => "10"})
    end)

    assert {:ok, _} = Worklogs.update(client, "PROJ-1", "10", time_spent: "2h")
    assert_received {:body, body, "/rest/api/3/issue/PROJ-1/worklog/10"}
    assert body["timeSpent"] == "2h"
  end

  test "delete passes estimate params" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    Req.Test.stub(name, fn conn ->
      send(self(), {:params, query_params(conn), conn.request_path})
      respond(conn, 204, nil)
    end)

    assert {:ok, nil} = Worklogs.delete(client, "PROJ-1", "10", adjust_estimate: "auto")
    assert_received {:params, params, "/rest/api/3/issue/PROJ-1/worklog/10"}
    assert params["adjustEstimate"] == "auto"
  end

  test "list streams the offset envelope" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    Req.Test.stub(name, fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)

      case conn.query_params do
        %{"startAt" => "1"} ->
          respond(conn, 200, %{"worklogs" => [%{"id" => "w2"}], "startAt" => 1, "total" => 2})

        _ ->
          respond(conn, 200, %{"worklogs" => [%{"id" => "w1"}], "startAt" => 0, "total" => 2})
      end
    end)

    ids =
      Worklogs.stream(client, "PROJ-1", max_results: 1)
      |> Stream.map(& &1["id"])
      |> Enum.to_list()

    assert ids == ["w1", "w2"]
  end
end
