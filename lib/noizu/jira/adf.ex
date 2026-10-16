defmodule Noizu.Jira.ADF do
  @moduledoc """
  Minimal Atlassian Document Format (ADF) helper.

  v3 requires ADF for descriptions, environment, comments, worklog comments, and
  textarea custom fields. `doc/1` converts plain text into a document with one
  paragraph per blank-line-separated block; single newlines become hard breaks:

      Noizu.Jira.ADF.doc("First line.\\n\\nSecond paragraph.")

  produces:

      %{
        "type" => "doc",
        "version" => 1,
        "content" => [
          %{"type" => "paragraph", "content" => [%{"type" => "text", "text" => "First line."}]},
          %{"type" => "paragraph", "content" => [%{"type" => "text", "text" => "Second paragraph."}]}
        ]
      }

  An ADF map (one with `"type" => "doc"`) is passed through untouched, so richly
  structured documents can be supplied directly wherever this library asks for a
  comment or description.

  〚📦:𓎝𔋀𓷧𓳼〛 Noizu.Jira.ADF :: Minimal Atlassian Document Format (ADF) helper.
  """

  @type adf :: map()

  @spec doc(String.t() | adf()) :: adf()
  @doc """
  How: takes `%{"type" => "doc"} = document`; returns `adf()`

  〚🔧:𓸋𓍲𔐐𓤨〛 doc :: doc/1
  """
  def doc(%{"type" => "doc"} = document), do: document

  def doc(text) when is_binary(text) do
    content =
      text
      |> String.split(~r/\n{2,}/, trim: true)
      |> Enum.map(&paragraph/1)

    %{"type" => "doc", "version" => 1, "content" => content}
  end

  defp paragraph(text) do
    content =
      text
      |> String.split("\n")
      |> Enum.map_intersperse(%{"type" => "hardBreak"}, fn line ->
        %{"type" => "text", "text" => line}
      end)

    %{"type" => "paragraph", "content" => content}
  end
end
