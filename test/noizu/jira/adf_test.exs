defmodule Noizu.Jira.ADFTest do
  use ExUnit.Case, async: true

  alias Noizu.Jira.ADF

  test "single paragraph" do
    assert ADF.doc("hello world") == %{
             "type" => "doc",
             "version" => 1,
             "content" => [
               %{
                 "type" => "paragraph",
                 "content" => [%{"type" => "text", "text" => "hello world"}]
               }
             ]
           }
  end

  test "blank lines split paragraphs" do
    doc = ADF.doc("first\n\nsecond\n\n\nthird")

    texts =
      for para <- doc["content"] do
        [%{"text" => text}] = para["content"]
        text
      end

    assert texts == ["first", "second", "third"]
  end

  test "single newlines become hardBreaks" do
    doc = ADF.doc("a\nb")

    assert doc["content"] == [
             %{
               "type" => "paragraph",
               "content" => [
                 %{"type" => "text", "text" => "a"},
                 %{"type" => "hardBreak"},
                 %{"type" => "text", "text" => "b"}
               ]
             }
           ]
  end

  test "empty text yields an empty document" do
    assert ADF.doc("") == %{"type" => "doc", "version" => 1, "content" => []}
  end

  test "ADF maps pass through untouched" do
    rich = %{"type" => "doc", "version" => 1, "content" => [%{"type" => "panel"}]}
    assert ADF.doc(rich) == rich
  end
end
