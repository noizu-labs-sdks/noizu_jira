defmodule Noizu.Jira.Pagination do
  # 〚📦:𓆃𓰃𓲉𓵐〛 Noizu.Jira.Pagination :: Noizu.Jira.Pagination module
  @moduledoc false

  # Stream machinery shared by every *_stream helper. Jira returns two paging
  # models (offset envelope and nextPageToken) and some list operations return
  # bare arrays; termination rules are defensive because total/isLast are not
  # guaranteed on every operation and empty pages are legal.
  #
  # Streams raise Noizu.Jira.Error on page failure — a lazy Stream has no error
  # channel, so this is a documented convention (see docs/API-CONTRACT.md).

  alias Noizu.Jira.Error

  @type page :: map()
  @type fetch :: (term() -> {:ok, page()} | {:error, Error.t()})
  @type next :: (page() -> {:more, (term() -> {:ok, page()} | {:error, Error.t()})} | :done)

  @spec stream(fetch(), (page() -> [term()]), next()) :: Enumerable.t()
  # 〚🔧:𔁄𔇪𔏇𓫱〛 stream :: stream/3
  def stream(fetch, items_fun, next_fun) do
    Stream.resource(
      fn -> :first end,
      fn
        :first ->
          case fetch.(:first) do
            {:ok, page} -> advance(page, items_fun, next_fun)
            {:error, %Error{} = error} -> raise error
          end

        {:more, thunk} ->
          case thunk.() do
            {:ok, page} -> advance(page, items_fun, next_fun)
            {:error, %Error{} = error} -> raise error
          end

        :done ->
          {:halt, :ok}
      end,
      fn _ -> :ok end
    )
  end

  @doc """
  Next step for an offset envelope (`{items, startAt, maxResults, total, isLast}`).

  The items key differs per endpoint (`values` on project/board listings,
  `comments`, `worklogs`, `issues` elsewhere), so `items_fun/1` extracts it.
  """
  @spec offset_next(page(), (pos_integer() -> {:ok, page()} | {:error, Error.t()}), (page() ->
                                                                                       [term()])) ::
          next_result()
  # 〚🔧:𔌹𔆕𔘍𓙾〛 offset_next :: offset_next/3
  def offset_next(page, refetch, items_fun \\ &Map.get(&1, "values", [])) do
    items = items_fun.(page)
    start_at = Map.get(page, "startAt") || 0
    total = Map.get(page, "total")
    is_last = Map.get(page, "isLast")

    cond do
      items == [] -> :done
      is_last == true -> :done
      is_integer(total) and start_at + length(items) >= total -> :done
      true -> {:more, fn -> refetch.(start_at + length(items)) end}
    end
  end

  @doc """
  Next step for a nextPageToken page.

  """
  @spec token_next(page(), (String.t() -> {:ok, page()} | {:error, Error.t()})) :: next_result()
  # 〚🔧:𓩰𔙸𔗲𔎈〛 token_next :: Next step for a nextPageToken page.
  def token_next(page, refetch) do
    case page["nextPageToken"] do
      token when is_binary(token) and token != "" -> {:more, fn -> refetch.(token) end}
      _ -> :done
    end
  end

  @doc "Next step for bare-array responses (stop when short of max_results or empty)."
  @spec array_next(
          [term()],
          (pos_integer() -> {:ok, [term()]} | {:error, Error.t()}),
          pos_integer(),
          pos_integer() | nil
        ) ::
          next_result()
  # 〚🔧:𔖋𓪯𓩠𓼅〛 array_next :: array_next/4
  def array_next([], _refetch, _next_start, _max_results), do: :done

  def array_next(items, refetch, next_start, max_results) do
    continue? = is_nil(max_results) or length(items) >= max_results

    if continue? do
      {:more, fn -> refetch.(next_start) end}
    else
      :done
    end
  end

  @type next_result :: {:more, (term() -> {:ok, page()} | {:error, Error.t()})} | :done

  defp advance(page, items_fun, next_fun) do
    items = items_fun.(page)

    case next_fun.(page) do
      {:more, thunk} -> {items, {:more, thunk}}
      :done -> {items, :done}
    end
  end
end
