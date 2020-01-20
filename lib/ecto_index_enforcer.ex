defmodule EctoIndexEnforcer do
  # Heavily inspired by https://github.com/sb8244/ecto_tenancy_enforcer
  defmacro __using__(opts) do
    raise_errors = opts[:raise_errors] || false
    validate_wheres = opts[:validate_wheres] || false
    validate_indexes = opts[:validate_indexes] || false

    quote do
      require Logger
      import EctoIndexEnforcer

      def prepare_query(_operation, query, opts) do
        with wheres <- collect_wheres(query),
             sources <- collect_sources(query),
             :ok <- validate_wheres(query, unquote(validate_wheres)),
             :ok <-
               validate_uses_indexes(wheres, sources, unquote(validate_indexes)) do
          {query, opts}
        else
          {:error, :query_without_wheres} ->
            maybe_raise({query, opts}, :query_without_wheres, unquote(raise_errors))

          {:error, :query_without_indexes} ->
            maybe_raise({query, opts}, :query_without_indexes, unquote(raise_errors))
        end
      end

      defp collect_sources(%{from: nil, joins: joins}) do
        # FIXME
        ["query" | join_sources(joins)]
      end

      defp collect_sources(%{from: %{source: source}, joins: joins}) do
        [from_sources(source) | join_sources(joins)]
      end

      defp join_sources(joins) do
        joins
        |> Enum.sort_by(& &1.ix)
        |> Enum.map(fn
          %Ecto.Query.JoinExpr{assoc: assoc = {_, _}} ->
            assoc

          %Ecto.Query.JoinExpr{source: {:fragment, _, _}} ->
            "fragment"

          %Ecto.Query.JoinExpr{source: %Ecto.Query{from: from}} ->
            from_sources(from.source)

          %Ecto.Query.JoinExpr{source: source} ->
            from_sources(source)
        end)
      end

      defp collect_wheres(%{wheres: source}) do
        source
        |> Enum.map(fn expression ->
          {source_index, name} = parse_expression(expression.expr)
          {source_index, Atom.to_string(name)}
        end)
      end

      defp parse_expression({_, _, [_, %Ecto.Query.Tagged{type: {source_index, name}} | _rest]}) do
        {source_index, name}
      end

      defp parse_expression({_, [], [{{:., [], [{:&, [], [source_index]}, name]}, _, _} | _rest]}) do
        {source_index, name}
      end

      defp parse_expression({:fragment, a, b}) do
        # FIXME: How to parse fragments?
        Logger.debug("[ecto_index_enforcer] Cannot parse fragments")

        {"fragment", nil}
      end

      defp parse_expression(other) do
        {nil, nil}
      end

      defp from_sources(%Ecto.SubQuery{query: query}), do: from_sources(query.from.source)
      defp from_sources({source, _schema}), do: source
      # FIXME
      defp from_sources(nil), do: "query"

      defp validate_wheres(_query, false) do
        :ok
      end

      defp validate_wheres(%{wheres: nil}, true) do
        {:error, :query_without_wheres}
      end

      defp validate_wheres(%{wheres: []}, true) do
        {:error, :query_without_wheres}
      end

      defp validate_wheres(query, true) do
        :ok
      end

      defp validate_uses_indexes(wheres, sources, false) do
        :ok
      end

      defp validate_uses_indexes(wheres, sources, true) do
        wheres
        |> Enum.map(fn {index, column} ->
          check_index(index, column, sources)
        end)
        |> Enum.any?(fn {_, _, valid} -> not valid end)
        |> case do
          true ->
            {:error, :query_without_indexes}

          false ->
            :ok
        end
      end

      defp check_index("fragment", _column, froms) do
        {nil, nil, true}
      end

      defp check_index(nil, column, froms) do
        {nil, nil, false}
      end

      defp check_index(index, column, froms) do
        table_name = Enum.at(froms, index)

        {table_name, column, EctoIndexEnforcer.IndexFinder.get_table_indexes(table_name, column)}
      end

      defp format_invalids(invalids) do
        Enum.join(
          Enum.map(invalids, fn {table_name, column, false} -> "#{table_name}.#{column}" end),
          ", "
        )
      end

      defp maybe_raise({query, _opts}, error_type, true) do
        Logger.error("Query with problems: #{error_type}: #{inspect(query)}")
        raise "Invalid query!"
      end

      defp maybe_raise({query, opts}, error_type, false) do
        Logger.warn("Query with problems: #{error_type}: #{inspect(query)}")
        {query, opts}
      end
    end
  end
end
