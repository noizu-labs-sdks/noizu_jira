defmodule Noizu.Jira.UsersTest do
  use ExUnit.Case, async: true

  import Noizu.Jira.TestSupport
  alias Noizu.Jira.Users

  test "me hits /myself" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    stub(name, :get, "/rest/api/3/myself", %{"accountId" => "5b1"})
    assert {:ok, %{"accountId" => "5b1"}} = Users.me(client)
  end

  test "get sends accountId" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    Req.Test.stub(name, fn conn ->
      send(self(), {:params, query_params(conn)})
      respond(conn, 200, %{"accountId" => "5b1"})
    end)

    assert {:ok, _} = Users.get(client, account_id: "5b1")
    assert_received {:params, %{"accountId" => "5b1"}}
  end

  test "search returns the raw array" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    Req.Test.stub(name, fn conn ->
      send(self(), {:params, query_params(conn)})
      respond(conn, 200, [%{"accountId" => "a"}, %{"accountId" => "b"}])
    end)

    assert {:ok, [%{"accountId" => "a"}, %{"accountId" => "b"}]} =
             Users.search(client, "ki", max_results: 2)

    assert_received {:params, %{"query" => "ki", "maxResults" => "2"}}
  end

  test "stream pages the array until a short page" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    Req.Test.stub(name, fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)

      case conn.query_params["startAt"] do
        "2" -> respond(conn, 200, [%{"accountId" => "c"}])
        nil -> respond(conn, 200, [%{"accountId" => "a"}, %{"accountId" => "b"}])
      end
    end)

    ids =
      Users.stream(client, "ki", max_results: 2)
      |> Stream.map(& &1["accountId"])
      |> Enum.to_list()

    assert ids == ["a", "b", "c"]
  end
end
