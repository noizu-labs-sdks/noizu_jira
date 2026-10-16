defmodule Noizu.Jira.AttachmentsTest do
  use ExUnit.Case, async: true

  import Noizu.Jira.TestSupport
  alias Noizu.Jira.Attachments

  @tmp System.tmp_dir!()

  defp write_fixture(name, content) do
    path = Path.join(@tmp, "noizu_jira_#{System.unique_integer([:positive])}_#{name}")
    File.write!(path, content)
    path
  end

  test "add streams multipart with the no-check header" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])
    path = write_fixture("trace.log", "line one\nline two\n")

    Req.Test.stub(name, fn conn ->
      send(self(), {:headers, conn.req_headers, conn.request_path})
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      send(self(), {:body, raw})
      respond(conn, 200, [%{"id" => "1", "filename" => "trace.log"}])
    end)

    try do
      assert {:ok, [%{"id" => "1"}]} = Attachments.add(client, "PROJ-1", path)
    after
      File.rm(path)
    end

    assert_received {:headers, headers, "/rest/api/3/issue/PROJ-1/attachments"}
    assert {"x-atlassian-token", "no-check"} = List.keyfind(headers, "x-atlassian-token", 0)

    content_type = List.keyfind(headers, "content-type", 0)
    assert {"content-type", "multipart/form-data; boundary=" <> _} = content_type

    assert_received {:body, raw}
    assert raw =~ ~s(filename="noizu_jira_)
    assert raw =~ ~s(trace.log")
    assert raw =~ "line one\nline two"
  end

  test "add honors the filename option" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])
    path = write_fixture("weird name.log", "x")

    Req.Test.stub(name, fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      send(self(), {:body, raw})
      respond(conn, 200, [%{"id" => "2"}])
    end)

    try do
      assert {:ok, _} = Attachments.add(client, "PROJ-1", path, filename: "trace.log")
    after
      File.rm(path)
    end

    assert_received {:body, raw}
    assert raw =~ "filename=\"trace.log\""
    refute raw =~ "weird name"
  end

  test "get returns attachment metadata" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    stub(name, :get, "/rest/api/3/attachment/1", %{"id" => "1", "size" => 3})
    assert {:ok, %{"size" => 3}} = Attachments.get(client, "1")
  end

  test "content returns the raw binary" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    Req.Test.stub(name, fn conn ->
      if conn.request_path == "/rest/api/3/attachment/content/1" do
        respond_binary(conn, 200, "text/plain", "RAWBYTES")
      else
        respond(conn, 500, %{"errorMessages" => ["unmatched"]})
      end
    end)

    assert {:ok, "RAWBYTES"} = Attachments.content(client, "1")
  end

  test "delete removes the attachment" do
    name = stub_name()
    client = basic_client(req: [plug: {Req.Test, name}])

    Req.Test.stub(name, fn conn ->
      if conn.method == "DELETE" and conn.request_path == "/rest/api/3/attachment/1" do
        respond(conn, 204, nil)
      else
        respond(conn, 500, %{"errorMessages" => ["unmatched"]})
      end
    end)

    assert {:ok, nil} = Attachments.delete(client, "1")
  end
end
