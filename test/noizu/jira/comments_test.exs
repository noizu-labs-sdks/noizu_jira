defmodule Noizu.Jira.CommentsTest do
  use ExUnit.Case, async: true

  import Noizu.Jira.TestSupport
  alias Noizu.Jira.Comments

  test "add wraps plain text in ADF" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    Req.Test.stub(name, fn conn ->
      {body, conn} = read_json_body(conn)
      send(self(), {:body, body})
      respond(conn, 201, %{"id" => "10000"})
    end)

    assert {:ok, %{"id" => "10000"}} = Comments.add(client, "PROJ-1", "nice work")
    assert_received {:body, body}
    assert body["body"]["type"] == "doc"
    assert [%{"text" => "nice work"}] = body["body"]["content"] |> hd() |> Map.get("content")
  end

  test "add passes ADF maps through" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    adf = %{"type" => "doc", "version" => 1, "content" => []}

    Req.Test.stub(name, fn conn ->
      {body, conn} = read_json_body(conn)
      send(self(), {:body, body})
      respond(conn, 201, %{"id" => "10001"})
    end)

    assert {:ok, _} = Comments.add(client, "PROJ-1", adf)
    assert_received {:body, %{"body" => ^adf}}
  end

  test "update wraps text in ADF" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    Req.Test.stub(name, fn conn ->
      {body, conn} = read_json_body(conn)
      send(self(), {:body, body, conn.request_path})
      respond(conn, 200, %{"id" => "10000"})
    end)

    assert {:ok, _} = Comments.update(client, "PROJ-1", "10000", "edited")
    assert_received {:body, body, "/rest/api/3/issue/PROJ-1/comment/10000"}
    assert body["body"]["type"] == "doc"
  end

  test "get and delete use the comment path" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    stub(name, :get, "/rest/api/3/issue/PROJ-1/comment/10000", %{"id" => "10000"})

    Req.Test.stub(name, fn conn ->
      if conn.method == "DELETE" and conn.request_path == "/rest/api/3/issue/PROJ-1/comment/10000" do
        respond(conn, 204, nil)
      else
        dispatch(conn, :get, "/rest/api/3/issue/PROJ-1/comment/10000", %{"id" => "10000"})
      end
    end)

    assert {:ok, %{"id" => "10000"}} = Comments.get(client, "PROJ-1", "10000")
    assert {:ok, nil} = Comments.delete(client, "PROJ-1", "10000")
  end

  test "stream walks the offset envelope" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    Req.Test.stub(name, fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)

      case conn.query_params do
        %{"startAt" => "1"} ->
          respond(conn, 200, %{
            "comments" => [%{"id" => "c2"}],
            "startAt" => 1,
            "total" => 2,
            "isLast" => true
          })

        _ ->
          respond(conn, 200, %{
            "comments" => [%{"id" => "c1"}],
            "startAt" => 0,
            "total" => 2,
            "isLast" => false
          })
      end
    end)

    ids =
      Comments.stream(client, "PROJ-1", max_results: 1)
      |> Stream.map(& &1["id"])
      |> Enum.to_list()

    assert ids == ["c1", "c2"]
  end
end
