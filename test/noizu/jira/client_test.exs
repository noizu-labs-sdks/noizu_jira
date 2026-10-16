defmodule Noizu.Jira.ClientTest do
  use ExUnit.Case, async: true

  import Noizu.Jira.TestSupport
  alias Noizu.Jira.Client

  describe "new/1" do
    test "basic auth client" do
      client = basic_client()

      assert %Client{} = client
      assert client.auth == {:basic, "user@example.test", "fake-token"}
      assert client.site == "example.atlassian.net"
      assert client.cloud_id == nil
      assert client.retry[:max_attempts] == 3
      assert client.retry[:base_sleep_ms] == 250
      assert client.retry[:max_sleep_ms] == 30_000
      assert Client.base_url(client) == "https://example.atlassian.net"
    end

    test "oauth client" do
      client = oauth_client()
      assert client.cloud_id == cloud_id()
      assert Client.base_url(client) == "https://api.atlassian.com/ex/jira/" <> cloud_id()
    end

    test "site normalization strips scheme and trailing slash" do
      client = Client.new(auth: {:basic, "a@b.test", "t"}, site: "https://example.atlassian.net/")
      assert client.site == "example.atlassian.net"
      assert Client.base_url(client) == "https://example.atlassian.net"
    end

    test "missing auth raises KeyError" do
      assert_raise KeyError, fn -> Client.new(site: "example.atlassian.net") end
    end

    test "basic auth without site raises ArgumentError" do
      assert_raise ArgumentError, ~r/:site is required/, fn ->
        Client.new(auth: {:basic, "a@b.test", "t"})
      end
    end

    test "oauth without cloud_id raises ArgumentError" do
      assert_raise ArgumentError, ~r/:cloud_id is required/, fn ->
        Client.new(auth: {:oauth, "tok"})
      end
    end

    test "invalid auth tuple raises ArgumentError" do
      assert_raise ArgumentError, ~r/invalid :auth/, fn ->
        Client.new(auth: {:weird, "x"}, site: "example.atlassian.net")
      end
    end

    test "retry overrides merge over defaults" do
      client = basic_client(retry: [max_attempts: 5])
      assert client.retry[:max_attempts] == 5
      assert client.retry[:base_sleep_ms] == 250
    end
  end

  describe "request building" do
    test "basic auth: host, path, and Authorization header" do
      name = stub_name()
      client = basic_client(req: [plug: {Req.Test, name}])

      stub(name, :get, "/rest/api/3/issue/PROJ-1", %{"key" => "PROJ-1"})

      Req.Test.stub(name, fn conn ->
        send(self(), {:conn, conn.method, conn.request_path, conn.req_headers, conn.host})
        dispatch(conn, :get, "/rest/api/3/issue/PROJ-1", %{"key" => "PROJ-1"})
      end)

      assert {:ok, %{"key" => "PROJ-1"}} = Noizu.Jira.Issues.get(client, "PROJ-1")

      assert_received {:conn, "GET", "/rest/api/3/issue/PROJ-1", headers, "example.atlassian.net"}

      expected = "Basic " <> Base.encode64("user@example.test:fake-token")
      assert {"authorization", ^expected} = List.keyfind(headers, "authorization", 0)
    end

    test "oauth: host, path prefix, and Bearer header" do
      name = stub_name()
      cid = cloud_id()
      client = oauth_client(req: [plug: {Req.Test, name}])

      Req.Test.stub(name, fn conn ->
        send(self(), {:conn, conn.method, conn.request_path, conn.req_headers, conn.host})

        dispatch(conn, :get, "/ex/jira/" <> cid <> "/rest/api/3/issue/PROJ-1", %{
          "key" => "PROJ-1"
        })
      end)

      assert {:ok, %{"key" => "PROJ-1"}} = Noizu.Jira.Issues.get(client, "PROJ-1")

      assert_received {:conn, "GET", "/ex/jira/" <> ^cid <> "/rest/api/3/issue/PROJ-1", headers,
                       "api.atlassian.com"}

      assert {"authorization", "Bearer fake-access-token"} =
               List.keyfind(headers, "authorization", 0)
    end

    test "path segments are percent-encoded defensively" do
      name = stub_name()
      client = basic_client(req: [plug: {Req.Test, name}])

      stub(name, :get, "/rest/api/3/issue/PROJ%2F1", %{"key" => "PROJ/1"})
      assert {:ok, _} = Noizu.Jira.Issues.get(client, "PROJ/1")
    end
  end
end
