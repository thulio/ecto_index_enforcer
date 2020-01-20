defmodule EctoIndexEnforcer.IndexFinder do
  use GenServer

  require Logger

  @query """
    select
      t.relname as table_name,
      i.relname as index_name,
      array_to_string(array_agg(a.attname), ', ') as column_names
  from
      pg_class t,
      pg_class i,
      pg_index ix,
      pg_attribute a
  where
      t.oid = ix.indrelid
      and i.oid = ix.indexrelid
      and a.attrelid = t.oid
      and a.attnum = ANY(ix.indkey)
      and t.relkind = 'r'
  group by
      t.relname,
      i.relname
  order by
      t.relname,
      i.relname;
  """

  def start_link(repo: repo) do
    GenServer.start_link(__MODULE__, repo: repo)
  end

  @impl true
  def init(repo: repo) do
    {:ok, %{repo: repo}, {:continue, :initial_work}}
  end

  @impl true
  def handle_continue(:initial_work, %{repo: repo} = state) do
    :ets.new(:indexes_table, [:set, :protected, :named_table])
    find(repo)
    {:noreply, state}
  end

  @impl true
  def handle_info(:find, %{repo: repo} = state) do
    find(repo)
    {:noreply, state}
  end

  def get_table_indexes(table_name, column) do
    [result | _other] = :ets.lookup(:indexes_table, table_name)
    {^table_name, indexes} = result

    column in indexes
  end

  def find(repo) do
    results = repo.query!(@query)

    results.rows
    |> Enum.map(fn result -> Enum.zip(results.columns, result) |> Enum.into(%{}) end)
    |> Enum.group_by(fn item -> Map.get(item, "table_name") end)
    |> Enum.map(fn {key, values} ->
      %{key => Enum.map(values, fn value -> Map.get(value, "column_names") end)}
    end)
    |> Enum.map(fn item ->
      table_name = item |> Map.keys() |> Enum.at(0)

      columns =
        item
        |> Map.get(table_name)
        |> Enum.map(fn index_columns -> String.split(index_columns) end)
        |> List.flatten()
        |> Enum.uniq()

      :ets.insert(:indexes_table, {table_name, columns})
    end)

    schedule_work()
  end

  defp schedule_work() do
    Process.send_after(self(), :find, 60_000)
  end
end
