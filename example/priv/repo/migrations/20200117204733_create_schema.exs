defmodule EctoIndexEnforcer.Repo.Migrations.CreateSchema do
  use Ecto.Migration

  def change do
    create table("my_schema") do
      add(:name, :string)
      add(:value, :float)
      add(:other_value, :decimal)
      add(:data, :map)
    end

    execute("CREATE INDEX ON my_schema((data->>'id'));")
    execute("CREATE INDEX ON my_schema(name);")
  end
end
