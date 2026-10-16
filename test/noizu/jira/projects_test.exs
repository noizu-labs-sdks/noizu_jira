defmodule Noizu.Jira.ProjectsTest do
  use ExUnit.Case, async: true

  import Noizu.Jira.TestSupport
  alias Noizu.Jira.Projects

  test "search returns the offset page" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    Req.Test.stub(name, fn conn ->
      send(self(), {:params, query_params(conn)})

      respond(conn, 200, %{
        "values" => [%{"key" => "PROJ"}],
        "startAt" => 0,
        "total" => 1,
        "isLast" => true
      })
    end)

    assert {:ok, page} = Projects.search(client, max_results: 5)
    assert page["total"] == 1
    assert_received {:params, %{"maxResults" => "5"}}
  end

  test "stream walks pages even without total/isLast" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    Req.Test.stub(name, fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)

      case conn.query_params["startAt"] do
        "2" -> respond(conn, 200, %{"values" => []})
        nil -> respond(conn, 200, %{"values" => [%{"key" => "A"}, %{"key" => "B"}]})
      end
    end)

    keys = Projects.stream(client, max_results: 2) |> Stream.map(& &1["key"]) |> Enum.to_list()
    assert keys == ["A", "B"]
  end

  test "get fetches by key" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    stub(name, :get, "/rest/api/3/project/PROJ", %{"key" => "PROJ", "name" => "Project"})
    assert {:ok, %{"name" => "Project"}} = Projects.get(client, "PROJ")
  end
end
