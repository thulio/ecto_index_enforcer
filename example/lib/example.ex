defmodule Example do
  @moduledoc """
  Documentation for Example.
  """
  import Ecto.Query
  alias Example.Repo
  alias Example.MySchema

  def without_where do
    from(ms in MySchema) |> Repo.all()
  end

  def with_where_and_primary_key do
    from(ms in MySchema, where: ms.id > 1) |> Repo.all()
    from(ms in MySchema, where: is_nil(ms.id)) |> Repo.all()
  end

  def with_where_and_index do
    from(ms in MySchema, where: ms.name == "John") |> Repo.all()
  end

  def with_where_and_without_index do
    from(ms in MySchema, where: ms.value > 0.0) |> Repo.all()
  end

  def with_where_and_like_on_index do
    from(ms in MySchema, where: like(ms.name, "John%")) |> Repo.all()
  end

  def fragment_with_where_and_primary_key do
    from(ms in MySchema, where: fragment("id > 1")) |> Repo.all()
  end

  def aggregation do
    from(ms in MySchema, select: count(ms.value), where: ms.id > 0) |> Repo.one()
  end

  def group_by do
    from(ms in MySchema,
      select: {ms.value, avg(ms.value)},
      group_by: [ms.value],
      where: ms.value > 1.0
    )
    |> Repo.all()
  end
end
