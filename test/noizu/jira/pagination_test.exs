defmodule Noizu.Jira.PaginationTest do
  use ExUnit.Case, async: true

  alias Noizu.Jira.{Error, Pagination}

  # Production contract: `Pagination.stream/3` calls the fetch fun once with
  # `:first`; subsequent fetches happen through arity-0 thunks produced by the
  # `*_next` helpers, each closing over its own next-page argument.

  describe "offset_next/2" do
    test "stops on empty page" do
      assert Pagination.offset_next(%{"values" => []}, fn _ -> flunk("should not refetch") end) ==
               :done
    end

    test "stops when isLast is true" do
      page = %{"values" => [1], "isLast" => true}
      assert Pagination.offset_next(page, fn _ -> flunk("should not refetch") end) == :done
    end

    test "stops when total reached" do
      page = %{"values" => [3, 4], "startAt" => 2, "total" => 4}
      assert Pagination.offset_next(page, fn _ -> flunk("should not refetch") end) == :done
    end

    test "continues when total/isLast absent (defensive)" do
      page = %{"values" => [1, 2], "startAt" => 0}

      assert {:more, thunk} = Pagination.offset_next(page, fn start -> {:ok, %{start: start}} end)
      assert {:ok, %{start: 2}} = thunk.()
    end

    test "continues while below total" do
      page = %{"values" => [1, 2], "startAt" => 0, "total" => 5, "isLast" => false}
      assert {:more, thunk} = Pagination.offset_next(page, fn start -> {:ok, %{start: start}} end)
      assert {:ok, %{start: 2}} = thunk.()
    end

    test "reads the items via the given extractor (comments/worklogs keys)" do
      page = %{"comments" => [%{"id" => "c1"}], "startAt" => 0, "total" => 2, "isLast" => false}

      assert {:more, thunk} =
               Pagination.offset_next(
                 page,
                 fn start -> {:ok, %{start: start}} end,
                 &Map.get(&1, "comments", [])
               )

      assert {:ok, %{start: 1}} = thunk.()
    end
  end

  describe "token_next/2" do
    test "follows nextPageToken" do
      assert {:more, thunk} =
               Pagination.token_next(%{"nextPageToken" => "abc"}, fn t -> {:ok, %{t: t}} end)

      assert {:ok, %{t: "abc"}} = thunk.()
    end

    test "stops on absent or empty token" do
      assert Pagination.token_next(%{}, fn _ -> flunk("should not refetch") end) == :done

      assert Pagination.token_next(%{"nextPageToken" => ""}, fn _ ->
               flunk("should not refetch")
             end) == :done
    end
  end

  describe "array_next/4" do
    test "stops on empty" do
      assert Pagination.array_next([], fn _ -> flunk("x") end, 0, 50) == :done
    end

    test "stops when page is short of max_results" do
      assert Pagination.array_next([1, 2], fn _ -> flunk("x") end, 2, 50) == :done
    end

    test "continues on a full page and passes the given next start" do
      assert {:more, thunk} =
               Pagination.array_next([1, 2], fn start -> {:ok, %{start: start}} end, 2, 2)

      assert {:ok, %{start: 2}} = thunk.()
    end

    test "continues until an empty page when max_results is unknown" do
      assert {:more, thunk} =
               Pagination.array_next([1], fn start -> {:ok, %{start: start}} end, 1, nil)

      assert {:ok, %{start: 1}} = thunk.()
    end
  end

  describe "stream/3" do
    test "concatenates pages via the next thunk" do
      pages = %{
        0 => %{"values" => [1, 2], "startAt" => 0, "total" => 3},
        2 => %{"values" => [3], "startAt" => 2, "total" => 3}
      }

      refetch = fn start -> {:ok, Map.fetch!(pages, start)} end

      stream =
        Pagination.stream(
          fn :first -> {:ok, Map.fetch!(pages, 0)} end,
          &Map.get(&1, "values"),
          fn page -> Pagination.offset_next(page, refetch) end
        )

      assert Enum.to_list(stream) == [1, 2, 3]
    end

    test "stops at isLast without a final empty page" do
      pages = %{
        0 => %{"values" => [1], "isLast" => false},
        1 => %{"values" => [2], "isLast" => true}
      }

      refetch = fn start -> {:ok, Map.fetch!(pages, start)} end

      stream =
        Pagination.stream(
          fn :first -> {:ok, Map.fetch!(pages, 0)} end,
          &Map.get(&1, "values"),
          fn page -> Pagination.offset_next(page, refetch) end
        )

      assert Enum.to_list(stream) == [1, 2]
    end

    test "raises Error on page failure" do
      fetch = fn :first -> {:error, Error.decode(500, %{"errorMessages" => ["boom"]})} end

      stream = Pagination.stream(fetch, & &1, fn _page -> :done end)

      assert_raise Error, "jira request failed (500): boom", fn -> Enum.to_list(stream) end
    end

    test "raises Error on mid-stream failure" do
      pages = %{
        0 => %{"values" => [1], "isLast" => false},
        1 => :error
      }

      fetch = fn
        :first -> {:ok, Map.fetch!(pages, 0)}
        1 -> {:error, Error.decode(500, %{"errorMessages" => ["mid"]})}
      end

      stream =
        Pagination.stream(
          fetch,
          &Map.get(&1, "values"),
          fn page -> Pagination.offset_next(page, fn start -> fetch.(start) end) end
        )

      assert_raise Error, "jira request failed (500): mid", fn -> Enum.to_list(stream) end
    end

    test "works lazily with Enum.take" do
      fetch = fn
        :first -> {:ok, %{"values" => List.duplicate(0, 100), "startAt" => 0}}
        start -> {:ok, %{"values" => List.duplicate(start, 100), "startAt" => start}}
      end

      stream =
        Pagination.stream(
          fetch,
          &Map.get(&1, "values"),
          fn page -> Pagination.offset_next(page, fn start -> fetch.(start) end) end
        )

      assert length(Enum.take(stream, 10)) == 10
    end
  end
end
