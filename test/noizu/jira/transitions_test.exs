defmodule Noizu.Jira.TransitionsTest do
  use ExUnit.Case, async: true

  import Noizu.Jira.TestSupport
  alias Noizu.Jira.Transitions

  test "list hits the transitions endpoint" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    stub(name, :get, "/rest/api/3/issue/PROJ-1/transitions", %{
      "transitions" => [%{"id" => "31", "name" => "Done"}]
    })

    assert {:ok, %{"transitions" => [%{"id" => "31"}]}} = Transitions.list(client, "PROJ-1")
  end

  test "perform posts the transition payload with fields" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    Req.Test.stub(name, fn conn ->
      {body, conn} = read_json_body(conn)
      send(self(), {:body, body})
      respond(conn, 204, nil)
    end)

    assert {:ok, nil} =
             Transitions.perform(client, "PROJ-1", "31",
               fields: %{"resolution" => %{"name" => "Done"}}
             )

    assert_received {:body, body}

    assert body == %{
             "transition" => %{"id" => "31"},
             "fields" => %{"resolution" => %{"name" => "Done"}}
           }
  end

  test "perform accepts integer transition ids" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    Req.Test.stub(name, fn conn ->
      {body, conn} = read_json_body(conn)
      send(self(), {:body, body})
      respond(conn, 204, nil)
    end)

    assert {:ok, nil} = Transitions.perform(client, "PROJ-1", 31)
    assert_received {:body, %{"transition" => %{"id" => "31"}}}
  end
end
