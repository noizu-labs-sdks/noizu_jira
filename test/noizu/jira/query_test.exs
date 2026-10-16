defmodule Noizu.Jira.QueryTest do
  use ExUnit.Case, async: true

  import Noizu.Jira.TestSupport
  alias Noizu.Jira.Request

  # Queries are encoded by the library, never by Req's `:params`, because Req
  # encodes list values as `key[]=` which the Jira API rejects. These tests pin
  # the exact wire query strings for the parameters whose style the API
  # documents (comma-separated vs repeated keys).

  describe "Request.params styles" do
    test ":csv joins list values with commas" do
      assert Request.params([fields: :fields], fields: ["summary", "status"]) ==
               [{"fields", "summary,status"}]
    end

    test ":csv passes scalars through, stringified" do
      assert Request.params([max_results: :maxResults, fail_fast: :failFast],
               max_results: 50,
               fail_fast: true
             ) == [{"maxResults", "50"}, {"failFast", "true"}]
    end

    test ":multi repeats the key per value" do
      assert Request.params([{:keys, :keys, :multi}], keys: ["PA", "PB"]) ==
               [{"keys", "PA"}, {"keys", "PB"}]
    end

    test ":multi passes scalars through as one pair" do
      assert Request.params([{:status, :status, :multi}], status: :live) ==
               [{"status", "live"}]
    end

    test "nil options are dropped" do
      assert Request.params([fields: :fields, expand: :expand], []) == []
    end
  end

  describe "wire query strings" do
    test "Issues.get encodes fields/expand/properties as comma-separated" do
      name = stub_name()
      client = basic_client(req: [plug: {Req.Test, name}])

      Req.Test.stub(name, fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        send(self(), {:qs, conn.query_string})
        respond(conn, 200, %{"key" => "P-1"})
      end)

      assert {:ok, _} =
               Noizu.Jira.Issues.get(client, "P-1",
                 fields: ["summary", "status"],
                 expand: ["changelog"],
                 properties: ["a", "b"]
               )

      assert_received {:qs, "fields=summary%2Cstatus&expand=changelog&properties=a%2Cb"}
    end

    test "Projects.search encodes keys/status as repeated keys" do
      name = stub_name()
      client = basic_client(req: [plug: {Req.Test, name}])

      Req.Test.stub(name, fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        send(self(), {:qs, conn.query_string})
        respond(conn, 200, %{"values" => [], "isLast" => true})
      end)

      assert {:ok, _} =
               Noizu.Jira.Projects.search(client, keys: ["PA", "PB"], status: [:live, :archived])

      assert_received {:qs, "keys=PA&keys=PB&status=live&status=archived"}
    end

    test "Users.search appends the positional query last" do
      name = stub_name()
      client = basic_client(req: [plug: {Req.Test, name}])

      Req.Test.stub(name, fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        send(self(), {:qs, conn.query_string})
        respond(conn, 200, [])
      end)

      assert {:ok, _} = Noizu.Jira.Users.search(client, "will", max_results: 5)
      assert_received {:qs, "maxResults=5&query=will"}
    end

    test "reserved characters are percent-encoded, not `[]`-ed" do
      name = stub_name()
      client = basic_client(req: [plug: {Req.Test, name}])

      Req.Test.stub(name, fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        send(self(), {:qs, conn.query_string})
        respond(conn, 200, [])
      end)

      assert {:ok, _} = Noizu.Jira.Users.search(client, "a b&c=d")
      assert_received {:qs, "query=a+b%26c%3Dd"}
      refute_received {:qs, "query[]=a b" <> _}
    end
  end
end
