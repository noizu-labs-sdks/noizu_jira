defmodule Noizu.Jira.SearchTest do
  use ExUnit.Case, async: true

  import Noizu.Jira.TestSupport
  alias Noizu.Jira.Search

  test "search posts jql and options to the replacement endpoint" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    Req.Test.stub(name, fn conn ->
      {body, conn} = read_json_body(conn)
      send(self(), {:body, body, conn.request_path})
      respond(conn, 200, %{"issues" => [%{"key" => "P-1"}], "isLast" => true})
    end)

    assert {:ok, page} =
             Search.search(client, "project = PROJ",
               max_results: 50,
               fields: ["summary"],
               next_page_token: "tok",
               fields_by_keys: true
             )

    assert_received {:body, body, "/rest/api/3/search/jql"}
    assert body["jql"] == "project = PROJ"
    assert body["maxResults"] == 50
    assert body["nextPageToken"] == "tok"
    assert body["fields"] == ["summary"]
    assert body["fieldsByKeys"] == true
    assert page["issues"] == [%{"key" => "P-1"}]
  end

  test "count posts to approximate-count" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    Req.Test.stub(name, fn conn ->
      {body, conn} = read_json_body(conn)
      send(self(), {:body, body, conn.request_path})
      respond(conn, 200, %{"count" => 1234})
    end)

    assert {:ok, %{"count" => 1234}} = Search.count(client, "project = PROJ")
    assert_received {:body, %{"jql" => "project = PROJ"}, "/rest/api/3/search/approximate-count"}
  end

  test "stream follows nextPageToken across three pages" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    Req.Test.stub(name, fn conn ->
      {body, conn} = read_json_body(conn)

      case body["nextPageToken"] do
        nil ->
          respond(conn, 200, %{
            "issues" => [%{"key" => "P-1"}],
            "isLast" => false,
            "nextPageToken" => "t1"
          })

        "t1" ->
          respond(conn, 200, %{
            "issues" => [%{"key" => "P-2"}],
            "isLast" => false,
            "nextPageToken" => "t2"
          })

        "t2" ->
          respond(conn, 200, %{
            "issues" => [%{"key" => "P-3"}, %{"key" => "P-4"}],
            "isLast" => true
          })
      end
    end)

    keys = Search.stream(client, "project = PROJ") |> Stream.map(& &1["key"]) |> Enum.to_list()
    assert keys == ["P-1", "P-2", "P-3", "P-4"]
  end

  test "stream starts from opts-provided first page config only" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    Req.Test.stub(name, fn conn ->
      {body, conn} = read_json_body(conn)
      send(self(), {:body, body})
      respond(conn, 200, %{"issues" => [], "isLast" => true})
    end)

    assert [] = Search.stream(client, "project = PROJ", max_results: 10) |> Enum.to_list()
    assert_received {:body, %{"maxResults" => 10}}
  end
end
